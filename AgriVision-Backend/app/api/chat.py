import logging
from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.db_models import Field, AIChatMessage, FieldRecommendation
from app.services.ai_advisor_service import chat_with_advisor
from app.core.auth import get_current_user

router = APIRouter(prefix="/fields/{field_id}/chat", tags=["Chat"])
logger = logging.getLogger(__name__)

class ChatMessageRequest(BaseModel):
    message: str

class ChatMessageResponse(BaseModel):
    id: UUID
    role: str
    content: str
    created_at: str

    class Config:
        from_attributes = True

@router.get("", response_model=List[ChatMessageResponse])
def get_chat_history(field_id: UUID, db: Session = Depends(get_db), current_user = Depends(get_current_user)):
    """Fetch the chat history for a field."""
    field = db.query(Field).filter(Field.id == field_id, Field.owner_id == current_user.id).first()
    if not field:
        raise HTTPException(status_code=404, detail="Field not found or access denied")
        
    messages = db.query(AIChatMessage).filter(
        AIChatMessage.field_id == field_id
    ).order_by(AIChatMessage.created_at.asc()).all()
    
    # We must convert created_at manually if needed, or rely on pydantic
    return [{"id": m.id, "role": m.role, "content": m.content, "created_at": m.created_at.isoformat()} for m in messages]

@router.post("", response_model=ChatMessageResponse)
async def post_chat_message(field_id: UUID, req: ChatMessageRequest, db: Session = Depends(get_db), current_user = Depends(get_current_user)):
    """Send a message to the AI Advisor, returning its contextual response."""
    field = db.query(Field).filter(Field.id == field_id, Field.owner_id == current_user.id).first()
    if not field:
        raise HTTPException(status_code=404, detail="Field not found or access denied")

    # 1. Save user message
    user_msg = AIChatMessage(field_id=field_id, role="user", content=req.message)
    db.add(user_msg)
    db.commit()
    db.refresh(user_msg)
    
    # 2. Gather context
    # Ideally fetch real satellite/sensor data here, for now using mocked or latest available
    # We'll fetch recent chat history
    history_records = db.query(AIChatMessage).filter(
        AIChatMessage.field_id == field_id
    ).order_by(AIChatMessage.created_at.asc()).limit(20).all()
    
    chat_history = [{"role": m.role, "content": m.content} for m in history_records]
    
    # Gather feedback from recent recommendations
    recent_recs = db.query(FieldRecommendation).filter(
        FieldRecommendation.field_id == field_id
    ).order_by(FieldRecommendation.created_at.desc()).limit(10).all()
    
    rec_history = [{"category": r.category, "advice": r.advice, "status": r.status, "date": str(r.created_at)} for r in recent_recs]
    
    # 3. Call AI Advisor
    ai_response_text = await chat_with_advisor(
        user_message=req.message,
        field_name=field.name,
        area_ha=field.area_ha or 0.0,
        ndvi=field.latest_ndvi,
        ndvi_trend="Stable", # Mock or calculate
        soil_data=None, # fetch from agromonitoring or db if hooked up
        sensor_summary=None, # fetch latest timescaledb aggregation
        weather=None, # fetch latest weather
        crop_type=field.crop_type,
        plantation_date=str(field.plantation_date) if field.plantation_date else None,
        recent_recommendations=rec_history,
        chat_history=chat_history
    )
    
    # 4. Save AI Response
    ai_msg = AIChatMessage(field_id=field_id, role="model", content=ai_response_text)
    db.add(ai_msg)
    db.commit()
    db.refresh(ai_msg)
    
    return {"id": ai_msg.id, "role": ai_msg.role, "content": ai_msg.content, "created_at": ai_msg.created_at.isoformat()}
