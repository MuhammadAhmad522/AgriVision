import logging
from uuid import UUID

import firebase_admin.auth as auth
from fastapi import APIRouter, Depends, status, BackgroundTasks
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.auth import RequireRole, get_current_user
from app.core.errors import APIError
from app.database import get_db
from app.models.db_models import User, Field, Sensor
from app.api.fields import queue_field_deletion

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/admin",
    tags=["admin"],
    dependencies=[Depends(RequireRole(["admin"]))]
)

class UserResponse(BaseModel):
    id: UUID
    email: str
    role: str
    created_at: str

@router.get("/users", response_model=list[UserResponse])
def get_all_users(db: Session = Depends(get_db)):
    users = db.query(User).order_by(User.created_at.desc()).all()
    return [
        UserResponse(
            id=u.id,
            email=u.email,
            role=u.role.value if hasattr(u.role, 'value') else u.role,
            created_at=u.created_at.isoformat()
        )
        for u in users
    ]

@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(
    user_id: UUID,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if user_id == current_user.id:
        raise APIError(400, "bad_request", "You cannot delete your own admin account.")

    target_user = db.query(User).filter(User.id == user_id).first()
    if not target_user:
        raise APIError(404, "not_found", "User not found.")

    # 1. Queue all fields for deletion (to clean up 3rd party providers, storage, sensors, etc)
    user_fields = db.query(Field).filter(Field.owner_id == target_user.id).all()
    for field in user_fields:
        queue_field_deletion(db, field, background_tasks)

    # 2. Delete user from Postgres
    db.delete(target_user)
    db.commit()

    # 3. Delete user from Firebase Auth
    try:
        auth.delete_user(target_user.firebase_uid)
        logger.info(f"Deleted Firebase user {target_user.firebase_uid}")
    except Exception as e:
        logger.error(f"Failed to delete Firebase user {target_user.firebase_uid}: {e}")
        # Not throwing error here since the DB deletion already succeeded

    return None

class TransferFieldRequest(BaseModel):
    new_owner_id: UUID

@router.post("/fields/{field_id}/transfer")
def transfer_field(
    field_id: UUID,
    req: TransferFieldRequest,
    db: Session = Depends(get_db)
):
    field = db.query(Field).filter(Field.id == field_id).with_for_update().first()
    if not field:
        raise APIError(404, "field_not_found", "Field not found.")

    new_owner = db.query(User).filter(User.id == req.new_owner_id).first()
    if not new_owner:
        raise APIError(404, "user_not_found", "Target user not found.")

    if field.owner_id == new_owner.id:
        raise APIError(400, "invalid_transfer", "Field is already owned by this user.")

    # Transfer field ownership
    field.owner_id = new_owner.id
    
    # Transfer associated sensors
    db.query(Sensor).filter(Sensor.field_id == field_id).update(
        {Sensor.owner_id: new_owner.id}, 
        synchronize_session=False
    )
    
    db.commit()
    return {"status": "success", "message": f"Field transferred to {new_owner.email}"}
