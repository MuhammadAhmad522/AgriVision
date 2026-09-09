"""Direct staff-to-farmer advisories.

The gap this closes: an agronomist reviewing a field had no way to tell the farmer
anything. The only farmer-facing notification the system produced was an automatic
"an agronomist approved a recommendation" line, and the "agronomist guidance" channel
addresses the AI, not the person who has to walk the field. Expert judgement that did not
happen to fit inside an AI recommendation's review notes simply never left the web app.
"""

from datetime import datetime, timezone
from typing import Annotated, Literal, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, Query, status
from pydantic import BaseModel, ConfigDict, Field as PydanticField
from sqlalchemy.orm import Session, joinedload

from app.api.fields import field_readable_by
from app.core.auth import RequireRole, get_current_user
from app.core.rate_limit import rate_limiter
from app.database import get_db
from app.models.db_models import User, UserNotification

router = APIRouter(tags=["Advisories"])

ADVISORY_CATEGORY = "expert_advisory"


class AdvisoryCreate(BaseModel):
    """Free-text advice from staff to the field's owner."""

    model_config = ConfigDict(extra="forbid")

    title: Annotated[str, PydanticField(min_length=3, max_length=120)]
    message: Annotated[str, PydanticField(min_length=3, max_length=4000)]
    priority: Literal["low", "normal", "high", "urgent"] = "normal"
    # Lets an advisory hang off the recommendation that prompted it, so the farmer's app
    # can open the advice next to the AI advice it responds to.
    recommendation_id: Optional[UUID] = None


class AdvisoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    title: str
    body: str
    priority: str
    category: str
    field_id: Optional[UUID]
    field_name: Optional[str]
    created_by_id: Optional[UUID]
    created_by_email: Optional[str]
    reference_id: Optional[str]
    reference_type: Optional[str]
    is_read: bool
    created_at: datetime


@router.post(
    "/api/fields/{field_id}/advisories",
    response_model=AdvisoryResponse,
    status_code=status.HTTP_201_CREATED,
)
async def send_advisory(
    field_id: UUID,
    advisory: AdvisoryCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(RequireRole(["admin", "agronomist"])),
):
    """Deliver an advisory to the field owner's notification inbox."""
    field = field_readable_by(db, current_user, field_id)

    # Staff-authored and farmer-visible, so it is rate limited like the other outbound
    # channels rather than left open to accidental repeat submits.
    await rate_limiter.check(f"advisory:{current_user.firebase_uid}:{field_id}", 30, 3600)

    notification = UserNotification(
        user_id=field.owner_id,
        title=advisory.title.strip(),
        body=advisory.message.strip(),
        priority=advisory.priority,
        category=ADVISORY_CATEGORY,
        field_id=field.id,
        created_by_id=current_user.id,
        reference_id=str(advisory.recommendation_id) if advisory.recommendation_id else None,
        reference_type="recommendation" if advisory.recommendation_id else "field",
    )
    db.add(notification)
    db.commit()
    db.refresh(notification)
    return notification


@router.get("/api/fields/{field_id}/advisories", response_model=list[AdvisoryResponse])
def list_advisories(
    field_id: UUID,
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Advisories sent on this field.

    Readable by the owner and by staff who can read the field, so an agronomist can see
    what has already been said before saying it again — and the farmer keeps a record.
    """
    field = field_readable_by(db, current_user, field_id)
    return (
        db.query(UserNotification)
        .options(joinedload(UserNotification.created_by), joinedload(UserNotification.field))
        .filter(
            UserNotification.field_id == field.id,
            UserNotification.category == ADVISORY_CATEGORY,
        )
        .order_by(UserNotification.created_at.desc())
        .limit(limit)
        .all()
    )
