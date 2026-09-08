"""Agronomist standing guidance for a field's AI recommendation engine.

The old design piggybacked on the agronomist chat thread's rolling summary: guidance
was one line in a 6000-char transcript that also stored the AI's replies, so it faded
after ~3 turns, took effect only on the next 5-minute scheduler cycle, and the farmer
was never told a human had adjusted anything.

This module makes guidance a first-class object:
  * durable + individually retractable directives (not a lossy chat blob)
  * adding or retracting one **immediately** queues a forced recommendation re-run
  * the field owner is notified in-app that their agronomist changed the engine
  * the portal can show which run actually applied each directive
"""

from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, Query, status
from sqlalchemy.orm import Session, joinedload

from app.api.fields import field_readable_by
from app.core.auth import RequireRole, get_current_user
from app.core.errors import APIError
from app.core.rate_limit import rate_limiter
from app.database import get_db
from app.models.db_models import Field, FieldGuidanceDirective, User, UserNotification
from app.schemas.pydantic_schemas import (
    GuidanceDirectiveCreate,
    GuidanceDirectiveMutationResponse,
    GuidanceDirectiveResponse,
)

router = APIRouter(tags=["Agronomist Guidance"])

GUIDANCE_NOTIFICATION_CATEGORY = "guidance_update"
_ACTIVE = "active"


def _queue_rerun(background_tasks: BackgroundTasks, field_id: UUID) -> None:
    # Imported lazily: app.services.scheduler pulls in the provider stack, and the API
    # module graph should not depend on it at import time.
    from app.services.scheduler import run_ai_by_field_id

    background_tasks.add_task(run_ai_by_field_id, field_id, force=True)


def _notify_owner(db: Session, field: Field, actor: User, directive: FieldGuidanceDirective, action: str) -> None:
    """action: 'added' | 'removed'."""
    who = (actor.display_name or actor.email or "An agronomist").strip()
    excerpt = directive.text if len(directive.text) <= 240 else directive.text[:237].rstrip() + "..."
    if action == "added":
        title = f"Guidance added: {field.name}"
        body = (
            f"{who} added a standing instruction that will shape the AI recommendations for "
            f'{field.name}:\n\n"{excerpt}"\n\nUpdated recommendations will appear shortly.'
        )
    else:
        title = f"Guidance removed: {field.name}"
        body = (
            f"{who} removed a standing instruction for {field.name}:\n\n"
            f'"{excerpt}"\n\nFuture AI recommendations will no longer follow it.'
        )
    db.add(
        UserNotification(
            user_id=field.owner_id,
            title=title,
            body=body,
            priority="normal",
            category=GUIDANCE_NOTIFICATION_CATEGORY,
            field_id=field.id,
            created_by_id=actor.id,
            reference_id=str(directive.id),
            reference_type="guidance_directive",
        )
    )


@router.get("/api/fields/{field_id}/guidance", response_model=list[GuidanceDirectiveResponse])
def list_guidance(
    field_id: UUID,
    include_retracted: bool = Query(True, description="Include recently retracted / replant-superseded directives."),
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Directives for this field. Readable by staff and by the field owner, so both sides
    can see exactly what a human has told the engine to do."""
    field_readable_by(db, current_user, field_id)
    query = (
        db.query(FieldGuidanceDirective)
        .options(joinedload(FieldGuidanceDirective.created_by))
        .filter(FieldGuidanceDirective.field_id == field_id)
    )
    if not include_retracted:
        query = query.filter(FieldGuidanceDirective.status == _ACTIVE)
    directives = query.all()
    # Active first (newest active at the top), then everything else newest-first.
    directives.sort(key=lambda d: (d.status != _ACTIVE, -(d.created_at.timestamp())))
    return directives[:limit]


@router.post(
    "/api/fields/{field_id}/guidance",
    response_model=GuidanceDirectiveMutationResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_guidance(
    field_id: UUID,
    payload: GuidanceDirectiveCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(RequireRole(["admin", "agronomist"])),
):
    field = field_readable_by(db, current_user, field_id, include_archived=False)
    await rate_limiter.check(f"guidance:{current_user.firebase_uid}:{field_id}", 30, 3600)

    text = payload.text.strip()

    # Idempotent against accidental double-submits and "I'll just send it again" retries:
    # an identical active directive already steering this field is a no-op.
    existing = (
        db.query(FieldGuidanceDirective)
        .options(joinedload(FieldGuidanceDirective.created_by))
        .filter(
            FieldGuidanceDirective.field_id == field_id,
            FieldGuidanceDirective.status == _ACTIVE,
            FieldGuidanceDirective.text == text,
        )
        .first()
    )
    if existing is not None:
        return GuidanceDirectiveMutationResponse(
            directive=GuidanceDirectiveResponse.model_validate(existing),
            ai_rerun_queued=False,
            deduplicated=True,
        )

    directive = FieldGuidanceDirective(
        field_id=field_id,
        text=text,
        status=_ACTIVE,
        created_by_id=current_user.id,
    )
    db.add(directive)
    db.flush()
    _notify_owner(db, field, current_user, directive, "added")
    db.commit()
    db.refresh(directive)

    _queue_rerun(background_tasks, field_id)
    return GuidanceDirectiveMutationResponse(
        directive=GuidanceDirectiveResponse.model_validate(directive),
        ai_rerun_queued=True,
    )


@router.delete(
    "/api/fields/{field_id}/guidance/{directive_id}",
    response_model=GuidanceDirectiveMutationResponse,
)
async def retract_guidance(
    field_id: UUID,
    directive_id: UUID,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(RequireRole(["admin", "agronomist"])),
):
    field = field_readable_by(db, current_user, field_id, include_archived=False)
    directive = (
        db.query(FieldGuidanceDirective)
        .options(joinedload(FieldGuidanceDirective.created_by))
        .filter(
            FieldGuidanceDirective.id == directive_id,
            FieldGuidanceDirective.field_id == field_id,
        )
        .first()
    )
    if directive is None:
        raise APIError(404, "guidance_not_found", "That guidance directive was not found.")
    if directive.status != _ACTIVE:
        # Already gone — return current state without re-notifying or re-running.
        return GuidanceDirectiveMutationResponse(
            directive=GuidanceDirectiveResponse.model_validate(directive),
            ai_rerun_queued=False,
            deduplicated=True,
        )

    directive.status = "retracted"
    directive.retracted_by_id = current_user.id
    directive.retracted_at = datetime.now(timezone.utc)
    _notify_owner(db, field, current_user, directive, "removed")
    db.commit()
    db.refresh(directive)

    _queue_rerun(background_tasks, field_id)
    return GuidanceDirectiveMutationResponse(
        directive=GuidanceDirectiveResponse.model_validate(directive),
        ai_rerun_queued=True,
    )
