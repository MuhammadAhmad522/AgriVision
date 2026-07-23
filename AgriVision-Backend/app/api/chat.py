import hashlib
import re
from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, Header, Query, Response, UploadFile
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.api.fields import owned_field
from app.core.auth import get_current_user
from app.core.config import settings
from app.core.errors import APIError
from app.core.rate_limit import rate_limiter
from app.database import get_db
from app.models.db_models import AIChatMessage, AIChatThread, ChatAttachment, FieldObservation, FieldRecommendation, User
from app.schemas.pydantic_schemas import ChatMessageResponse, ChatTurnResponse, clean_text
from app.services.ai_advisor_service import get_ai_provider
from app.services.chat_media_service import SanitizedImage, get_chat_media_storage, sanitize_upload

router = APIRouter(prefix="/api/fields/{field_id}/chat", tags=["Chat"])


def _thread_for_field(db: Session, field_id: UUID) -> AIChatThread:
    thread = db.query(AIChatThread).filter(AIChatThread.field_id == field_id).first()
    if thread is None:
        thread = AIChatThread(field_id=field_id)
        db.add(thread)
        db.flush()
    return thread


def _message_response(db: Session, message: AIChatMessage) -> dict:
    attachments = db.query(ChatAttachment).filter(ChatAttachment.message_id == message.id).order_by(ChatAttachment.created_at.asc()).all()
    return {
        "id": message.id,
        "role": message.role,
        "content": message.content,
        "status": message.status,
        "created_at": message.created_at,
        "attachments": [
            {
                "id": item.id,
                "mime_type": item.mime_type,
                "byte_size": item.byte_size,
                "width": item.width,
                "height": item.height,
                "url": f"/api/fields/{message.field_id}/chat/attachments/{item.id}",
            }
            for item in attachments
        ],
    }


def _existing_turn(db: Session, field_id: UUID, key: str) -> dict | None:
    user_message = db.query(AIChatMessage).filter(
        AIChatMessage.field_id == field_id,
        AIChatMessage.role == "user",
        AIChatMessage.idempotency_key == key,
    ).first()
    if user_message is None:
        return None
    assistant = db.query(AIChatMessage).filter(AIChatMessage.reply_to_message_id == user_message.id).first()
    if assistant is None:
        raise APIError(409, "chat_turn_incomplete", "This chat turn is still being processed.", retryable=True)
    return {"user_message": _message_response(db, user_message), "assistant_message": _message_response(db, assistant)}


def _lock_turn(db: Session, field_id: UUID, key: str) -> None:
    """Serialize duplicate submissions across workers without persisting a draft row."""
    digest = hashlib.sha256(f"{field_id}:{key}".encode("utf-8")).digest()[:8]
    lock_key = int.from_bytes(digest, byteorder="big", signed=True)
    db.execute(text("SELECT pg_advisory_xact_lock(:key)"), {"key": lock_key})


def _update_rolling_summary(thread: AIChatThread, user_text: str, assistant_text: str) -> None:
    user_excerpt = user_text.strip() or "[field image submitted]"
    turn = f"Farmer: {user_excerpt[:800]}\nAdvisor: {assistant_text.strip()[:1600]}"
    combined = f"{thread.rolling_summary}\n\n{turn}" if thread.rolling_summary else turn
    # Bound database/prompt growth while retaining the newest decisions and context.
    thread.rolling_summary = combined[-6000:]


@router.get("", response_model=list[ChatMessageResponse])
def get_history(
    field_id: UUID,
    limit: int = Query(100, ge=1, le=200),
    before: datetime | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    owned_field(db, current_user, field_id)
    query = db.query(AIChatMessage).filter(AIChatMessage.field_id == field_id)
    if before:
        query = query.filter(AIChatMessage.created_at < before)
    messages = query.order_by(AIChatMessage.created_at.desc()).limit(limit).all()
    messages.reverse()
    return [_message_response(db, message) for message in messages]


@router.get("/attachments/{attachment_id}")
def get_attachment(
    field_id: UUID,
    attachment_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    owned_field(db, current_user, field_id)
    attachment = db.query(ChatAttachment).filter(ChatAttachment.id == attachment_id, ChatAttachment.field_id == field_id).first()
    if attachment is None:
        raise APIError(404, "attachment_not_found", "Attachment not found.")
    content = get_chat_media_storage().read(attachment.storage_key)
    return Response(content=content, media_type=attachment.mime_type, headers={"Content-Disposition": "inline"})


@router.post("", response_model=ChatTurnResponse)
async def post_message(
    field_id: UUID,
    message: str = Form(default=""),
    images: list[UploadFile] | None = File(default=None),
    idempotency_key: str = Header(alias="Idempotency-Key"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    field = owned_field(db, current_user, field_id, include_archived=False)
    if not re.fullmatch(r"[A-Za-z0-9._:-]{8,100}", idempotency_key):
        raise APIError(422, "invalid_idempotency_key", "The chat request identifier is invalid.")
    _lock_turn(db, field_id, idempotency_key)
    existing = _existing_turn(db, field_id, idempotency_key)
    if existing:
        return existing

    uploads = images or []
    if len(uploads) > settings.CHAT_MAX_IMAGES:
        raise APIError(422, "too_many_images", "Attach no more than three images.")
    try:
        normalized = clean_text(message) if message.strip() else ""
    except ValueError as exc:
        raise APIError(422, "invalid_message", "The chat message contains unsupported characters.") from exc
    if len(normalized) > 2000:
        raise APIError(422, "message_too_long", "Chat messages must be 2,000 characters or shorter.")
    if not normalized and not uploads:
        raise APIError(422, "empty_chat_turn", "Enter a message or attach an image.")

    await rate_limiter.check(f"chat:{current_user.firebase_uid}:{field_id}", 20, 3600)
    sanitized: list[SanitizedImage] = [await sanitize_upload(upload) for upload in uploads]
    thread = _thread_for_field(db, field_id)
    history = (
        db.query(AIChatMessage)
        .filter(AIChatMessage.field_id == field_id)
        .order_by(AIChatMessage.created_at.desc())
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
            {"category": item.category, "advice": item.advice, "feedback": item.status, "evidence": item.evidence}
            for item in recommendations
        ],
        "rolling_summary": thread.rolling_summary,
        "history": [{"role": item.role, "content": item.content} for item in history],
        "submitted_images": [{"mime_type": item.mime_type, "width": item.width, "height": item.height} for item in sanitized],
    }

    # The provider call happens before persistence so failures cannot create invisible orphan messages.
    response_text = await get_ai_provider().chat(normalized or "Assess the attached field image.", context, sanitized)
    storage = get_chat_media_storage()
    stored_keys: list[str] = []
    try:
        user_message = AIChatMessage(
            field_id=field_id,
            thread_id=thread.id,
            role="user",
            content=normalized,
            idempotency_key=idempotency_key,
            status="completed",
        )
        db.add(user_message)
        db.flush()
        for image in sanitized:
            key = storage.put(field_id, image)
            stored_keys.append(key)
            db.add(ChatAttachment(
                field_id=field_id,
                message_id=user_message.id,
                storage_key=key,
                mime_type=image.mime_type,
                byte_size=len(image.data),
                width=image.width,
                height=image.height,
                sha256=image.sha256,
            ))
        assistant = AIChatMessage(
            field_id=field_id,
            thread_id=thread.id,
            reply_to_message_id=user_message.id,
            role="model",
            content=response_text,
            status="completed",
        )
        db.add(assistant)
        _update_rolling_summary(thread, normalized, response_text)
        thread.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(user_message)
        db.refresh(assistant)
        return {"user_message": _message_response(db, user_message), "assistant_message": _message_response(db, assistant)}
    except Exception:
        db.rollback()
        for key in stored_keys:
            try:
                storage.delete(key)
            except Exception:
                pass
        raise
