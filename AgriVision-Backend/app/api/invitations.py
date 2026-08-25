from typing import List

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.auth import RequireRole, get_current_user
from app.core.errors import APIError
from app.database import get_db
from app.models.db_models import Invitation, User, UserRole
from app.schemas.pydantic_schemas import InvitationCreate, InvitationResponse

router = APIRouter(prefix="/api/invitations", tags=["Invitations"])

@router.post("", response_model=InvitationResponse)
def create_invitation(
    invite_data: InvitationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(RequireRole(["admin"]))
):
    # Check if a pending invite already exists
    existing_invite = db.query(Invitation).filter(
        Invitation.email == invite_data.email,
        Invitation.status == "pending"
    ).first()

    if existing_invite:
        # Instead of rejecting, we treat this as a resend request.
        # Update the role in case the admin changed their mind, and return it.
        existing_invite.role = invite_data.role
        db.commit()
        db.refresh(existing_invite)
        return existing_invite

    # Check if user already exists
    existing_user = db.query(User).filter(User.email == invite_data.email).first()
    if existing_user and existing_user.role != UserRole.mobile_user:
        raise APIError(400, "user_exists", f"User already exists and has role {existing_user.role}.")

    db_invite = Invitation(
        email=invite_data.email,
        role=invite_data.role,
        invited_by_id=current_user.id
    )
    db.add(db_invite)
    db.commit()
    db.refresh(db_invite)

    return db_invite

@router.get("", response_model=List[InvitationResponse])
def get_invitations(
    db: Session = Depends(get_db),
    current_user: User = Depends(RequireRole(["admin"]))
):
    invitations = db.query(Invitation).order_by(Invitation.created_at.desc()).all()
    return invitations
