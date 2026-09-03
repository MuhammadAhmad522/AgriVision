from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.auth import get_current_user
from app.database import get_db
from app.models.db_models import User, UserNotification
from pydantic import BaseModel, ConfigDict
from datetime import datetime

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

@router.get("", response_model=list[NotificationResponse])
def get_notifications(
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return (
        db.query(UserNotification)
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
