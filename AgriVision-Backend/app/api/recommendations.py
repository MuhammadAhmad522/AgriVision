from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.fields import field_readable_by, owned_field
from app.core.auth import RequireRole, get_current_user
from app.core.errors import APIError
from app.core.rate_limit import rate_limiter
from app.database import get_db
from app.models.db_models import FieldRecommendation, User
from app.schemas.pydantic_schemas import RecommendationFeedback, RecommendationOutcome, RecommendationResponse, RecommendationExpertValidation

router = APIRouter(tags=["AI Recommendations"])


@router.get("/api/fields/{field_id}/recommendations", response_model=list[RecommendationResponse])
@router.get("/api/fields/{field_id}/recommendations/", response_model=list[RecommendationResponse], include_in_schema=False)
def get_recommendations(
    field_id: UUID,
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    field_readable_by(db, current_user, field_id)
    return (
        db.query(FieldRecommendation)
        .filter(FieldRecommendation.field_id == field_id, FieldRecommendation.status != "superseded")
        .order_by(FieldRecommendation.created_at.desc())
        .limit(limit)
        .all()
    )


def _apply_feedback(recommendation_id: UUID, feedback: RecommendationFeedback, db: Session, current_user: User, field_id: UUID | None = None):
    query = db.query(FieldRecommendation).filter(FieldRecommendation.id == recommendation_id)
    if field_id:
        query = query.filter(FieldRecommendation.field_id == field_id)
    recommendation = query.first()
    if recommendation is None:
        raise APIError(404, "recommendation_not_found", "Recommendation not found.")
    owned_field(db, current_user, recommendation.field_id)
    from datetime import datetime, timezone

    recommendation.status = feedback.status
    recommendation.feedback_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(recommendation)
    return recommendation


@router.post("/api/recommendations/{recommendation_id}/feedback", response_model=RecommendationResponse)
def update_feedback(recommendation_id: UUID, feedback: RecommendationFeedback, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return _apply_feedback(recommendation_id, feedback, db, current_user)


@router.put("/api/fields/{field_id}/recommendations/{recommendation_id}/feedback", response_model=RecommendationResponse, include_in_schema=False)
def update_feedback_compat(field_id: UUID, recommendation_id: UUID, feedback: RecommendationFeedback, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return _apply_feedback(recommendation_id, feedback, db, current_user, field_id)


@router.get("/api/recommendations/expert/pending", response_model=list[RecommendationResponse])
def get_expert_pending_recommendations(
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(RequireRole(["agronomist"])),
):
    return (
        db.query(FieldRecommendation)
        .filter(FieldRecommendation.expert_status == "pending")
        .filter(FieldRecommendation.requires_expert_confirmation == True)
        .filter(FieldRecommendation.status != "superseded")
        .order_by(FieldRecommendation.created_at.desc())
        .limit(limit)
        .all()
    )


@router.post("/api/recommendations/{recommendation_id}/expert-validate", response_model=RecommendationResponse)
def expert_validate(
    recommendation_id: UUID,
    validation: RecommendationExpertValidation,
    db: Session = Depends(get_db),
    current_user: User = Depends(RequireRole(["agronomist"])),
):
    recommendation = db.query(FieldRecommendation).filter(FieldRecommendation.id == recommendation_id).first()
    if recommendation is None:
        raise APIError(404, "recommendation_not_found", "Recommendation not found.")
    # Staff can review any recommendation on a field they can read, not only ones the
    # AI already flagged with requires_expert_confirmation.
    field_readable_by(db, current_user, recommendation.field_id)

    recommendation.expert_status = validation.status
    if validation.notes is not None:
        recommendation.expert_notes = validation.notes
        
    db.commit()
    db.refresh(recommendation)
    return recommendation


@router.post("/api/recommendations/{recommendation_id}/outcome", response_model=RecommendationResponse)
def record_outcome(
    recommendation_id: UUID,
    outcome: RecommendationOutcome,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    recommendation = db.query(FieldRecommendation).filter(FieldRecommendation.id == recommendation_id).first()
    if recommendation is None:
        raise APIError(404, "recommendation_not_found", "Recommendation not found.")
    owned_field(db, current_user, recommendation.field_id)
    if recommendation.status != "implemented":
        raise APIError(409, "recommendation_not_implemented", "Mark the recommendation as implemented before recording its outcome.")
    from datetime import datetime, timezone

    recommendation.outcome = outcome.outcome
    recommendation.outcome_notes = outcome.notes
    recommendation.outcome_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(recommendation)
    return recommendation


@router.post("/api/fields/{field_id}/recommendations", response_model=list[RecommendationResponse])
@router.post("/api/fields/{field_id}/recommendations/refresh/", response_model=list[RecommendationResponse], include_in_schema=False)
async def trigger_refresh(
    field_id: UUID,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Triggering a re-analysis is a request for the AI to reconsider, not a farmer-only
    # mutation, so staff reviewing a field (e.g. right after leaving agronomist guidance)
    # can trigger it too.
    field_readable_by(db, current_user, field_id, include_archived=False)
    await rate_limiter.check(f"ai-refresh:{current_user.firebase_uid}:{field_id}", 10, 3600)
    from app.services.scheduler import run_ai_by_field_id

    background_tasks.add_task(run_ai_by_field_id, field_id, force=True)
    return (
        db.query(FieldRecommendation)
        .filter(FieldRecommendation.field_id == field_id, FieldRecommendation.status != "superseded")
        .order_by(FieldRecommendation.created_at.desc())
        .limit(20)
        .all()
    )

