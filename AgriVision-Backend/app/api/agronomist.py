import re
from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, Header, Query
from sqlalchemy import case
from sqlalchemy.orm import Session

from app.api.chat import _existing_turn, _lock_turn, _message_response, _thread_for_field, _update_rolling_summary
from app.api.fields import field_readable_by
from app.core.auth import RequireRole, get_current_user
from app.core.errors import APIError
from app.core.rate_limit import rate_limiter
from app.database import get_db
from app.models.db_models import AIChatMessage, FieldObservation, FieldRecommendation, User
from app.schemas.pydantic_schemas import ChatMessageRequest, ChatTurnResponse, ChatMessageResponse
from app.services.ai_advisor_service import get_ai_provider

router = APIRouter(prefix="/api/fields/{field_id}/agronomist-chat", tags=["Agronomist"])


@router.get("", response_model=list[ChatMessageResponse])
def get_agronomist_history(
    field_id: UUID,
    limit: int = Query(100, ge=1, le=200),
    before: datetime | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(RequireRole(["agronomist"])),
):
    field_readable_by(db, current_user, field_id)
    thread = _thread_for_field(db, field_id, channel="agronomist")
    query = db.query(AIChatMessage).filter(AIChatMessage.thread_id == thread.id)
    if before:
        query = query.filter(AIChatMessage.created_at < before)
    messages = (
        query.order_by(
            AIChatMessage.created_at.desc(),
            case((AIChatMessage.role == "model", 0), else_=1),
        )
        .limit(limit)
        .all()
    )
    messages.reverse()
    return [_message_response(db, message, field_id) for message in messages]


@router.post("", response_model=ChatTurnResponse)
async def post_agronomist_message(
    field_id: UUID,
    body: ChatMessageRequest,
    idempotency_key: str = Header(alias="Idempotency-Key"),
    db: Session = Depends(get_db),
    current_user: User = Depends(RequireRole(["agronomist"])),
):
    field = field_readable_by(db, current_user, field_id)
    if not re.fullmatch(r"[A-Za-z0-9._:-]{8,100}", idempotency_key):
        raise APIError(422, "invalid_idempotency_key", "The chat request identifier is invalid.")

    thread = _thread_for_field(db, field_id, channel="agronomist")
    _lock_turn(db, field_id, idempotency_key)
    existing = _existing_turn(db, thread.id, idempotency_key, field_id)
    if existing:
        return existing

    await rate_limiter.check(f"agronomist-chat:{current_user.firebase_uid}:{field_id}", 30, 3600)

    history = (
        db.query(AIChatMessage)
        .filter(AIChatMessage.thread_id == thread.id)
        .order_by(
            AIChatMessage.created_at.desc(),
            case((AIChatMessage.role == "model", 0), else_=1),
        )
        .limit(20)
        .all()
    )
    history.reverse()
    recommendations = (
        db.query(FieldRecommendation)
        .filter(FieldRecommendation.field_id == field_id)
        .order_by(FieldRecommendation.created_at.desc())
        .limit(10)
        .all()
    )
    observations = (
        db.query(FieldObservation)
        .filter(FieldObservation.field_id == field_id)
        .order_by(FieldObservation.observed_at.desc())
        .limit(30)
        .all()
    )
    context = {
        "field": {
            "name": field.name,
            "area_ha": field.area_ha,
            "crop_type": field.crop_type,
            "planted": field.plantation_date.isoformat() if field.plantation_date else None,
            "region": "Punjab, Pakistan",
        },
        "latest_ndvi": field.latest_ndvi,
        "observations": [
            {"metric": item.metric, "value": item.value, "payload": item.payload, "at": item.observed_at.isoformat(), "expires_at": item.expires_at.isoformat() if item.expires_at else None}
            for item in observations
        ],
        "recommendations": [
            {"category": item.category, "advice": item.advice, "feedback": item.status, "expert_status": item.expert_status}
            for item in recommendations
        ],
        "rolling_summary": thread.rolling_summary,
        "history": [{"role": item.role, "content": item.content} for item in history],
    }

    response_text = await get_ai_provider().chat(body.message, context, None, audience="agronomist")
    try:
        now = datetime.now(timezone.utc)
        user_message = AIChatMessage(
            thread_id=thread.id,
            role="user",
            content=body.message,
            idempotency_key=idempotency_key,
            status="completed",
            created_at=now,
        )
        db.add(user_message)
        db.flush()
        assistant = AIChatMessage(
            thread_id=thread.id,
            reply_to_message_id=user_message.id,
            role="model",
            content=response_text,
            status="completed",
            created_at=now + timedelta(microseconds=1000),
        )
        db.add(assistant)
        _update_rolling_summary(thread, body.message, response_text, speaker="Agronomist")
        thread.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(user_message)
        db.refresh(assistant)
        return {"user_message": _message_response(db, user_message, field_id), "assistant_message": _message_response(db, assistant, field_id)}
    except Exception:
        db.rollback()
        raise
