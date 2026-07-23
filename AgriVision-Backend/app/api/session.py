from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.fields import field_to_response
from app.core.auth import get_current_user
from app.core.config import settings
from app.database import get_db
from app.models.db_models import Field, User
from app.schemas.pydantic_schemas import SessionBootstrapResponse

router = APIRouter(prefix="/api/session", tags=["Session"])


@router.post("/bootstrap", response_model=SessionBootstrapResponse)
def bootstrap(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    fields = (
        db.query(Field)
        .filter(Field.owner_id == current_user.id, Field.status == "active")
        .order_by(Field.created_at.asc())
        .all()
    )
    return SessionBootstrapResponse(
        user=current_user,
        fields=[field_to_response(field, db) for field in fields],
        active_field_limit=settings.ACTIVE_FIELD_LIMIT,
        active_field_count=len(fields),
    )
