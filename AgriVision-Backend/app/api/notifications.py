from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.auth import get_current_user
from app.database import get_db
from app.models.db_models import User, UserNotification
from pydantic import BaseModel, ConfigDict
from datetime import datetime
from sqlalchemy.orm import joinedload

router = APIRouter(prefix="/api/notifications", tags=["Notifications"])

class NotificationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    title: str
    body: str
    reference_id: str | None
    reference_type: str | None
    is_read: bool
    created_at: datetime
    # Who sent it, about which field, and how urgent. Without these an advisory is an
    # anonymous line of text in an inbox belonging to a farmer with several fields.
    priority: str
    category: str
    field_id: UUID | None
    field_name: str | None
    created_by_id: UUID | None
    created_by_email: str | None

@router.get("", response_model=list[NotificationResponse])
def get_notifications(
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return (
        db.query(UserNotification)
        .options(joinedload(UserNotification.created_by), joinedload(UserNotification.field))
        .filter(UserNotification.user_id == current_user.id)
        .order_by(UserNotification.created_at.desc())
        .limit(limit)
        .all()
    )

@router.post("/{notification_id}/read", response_model=NotificationResponse)
def mark_notification_read(
    notification_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    from app.core.errors import APIError
    notif = db.query(UserNotification).filter(UserNotification.id == notification_id, UserNotification.user_id == current_user.id).first()
    if not notif:
        raise APIError(404, "not_found", "Notification not found")
    notif.is_read = True
    db.commit()
    db.refresh(notif)
    return notif


@router.post("/read-all")
def mark_all_notifications_read(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Clear the unread badge in one call.

    The inbox had no way to do this: a farmer who received a run of advisories had to open
    each one to get the badge back to zero, which trains people to ignore the badge.
    """
    updated = (
        db.query(UserNotification)
        .filter(UserNotification.user_id == current_user.id, UserNotification.is_read == False)  # noqa: E712
        .update({UserNotification.is_read: True}, synchronize_session=False)
    )
    db.commit()
    return {"updated": updated}
