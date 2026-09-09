from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.fields import field_readable_by, owned_field
from app.core.auth import RequireRole, get_current_user
from app.core.errors import APIError
from app.core.rate_limit import rate_limiter
from app.database import get_db
from app.models.db_models import AIAnalysisRun, FieldRecommendation, FieldSeasonMemory, User
from app.schemas.pydantic_schemas import AnalysisRunDetailResponse, RecommendationFeedback, RecommendationOutcome, RecommendationResponse, RecommendationExpertValidation, SeasonMemoryResponse

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


@router.get("/api/fields/{field_id}/season-memory", response_model=SeasonMemoryResponse)
def get_season_memory(
    field_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    field_readable_by(db, current_user, field_id)
    memory = (
        db.query(FieldSeasonMemory)
        .filter(FieldSeasonMemory.field_id == field_id, FieldSeasonMemory.season_ended_at.is_(None))
        .first()
    )
    if memory is None:
        raise APIError(404, "season_memory_not_found", "No season memory yet for this field.")
    return memory


def _apply_feedback(recommendation_id: UUID, feedback: RecommendationFeedback, db: Session, current_user: User, field_id: UUID | None = None):
    query = db.query(FieldRecommendation).filter(FieldRecommendation.id == recommendation_id)
    if field_id:
        query = query.filter(FieldRecommendation.field_id == field_id)
    recommendation = query.first()
    if recommendation is None:
        raise APIError(404, "recommendation_not_found", "Recommendation not found.")
    owned_field(db, current_user, recommendation.field_id)
    from datetime import datetime, timezone
    import uuid
    from sqlalchemy.orm.attributes import flag_modified

    recommendation.status = feedback.status
    recommendation.feedback_at = datetime.now(timezone.utc)
    
    # Update Season Memory Journal
    memory = db.query(FieldSeasonMemory).filter(
        FieldSeasonMemory.field_id == recommendation.field_id,
        FieldSeasonMemory.season_ended_at.is_(None)
    ).first()
    
    if memory:
        action_verb = "implemented" if feedback.status == "implemented" else "ignored"
        event = {
            "id": str(uuid.uuid4()),
            "date": datetime.now(timezone.utc).isoformat(),
            "description": f"Farmer {action_verb} AI advice: {recommendation.category}",
            "source": "user",
            "type": "feedback"
        }
        if not isinstance(memory.key_events, list):
            memory.key_events = []
        memory.key_events.append(event)
        flag_modified(memory, "key_events")

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


@router.get("/api/recommendations/{recommendation_id}/analysis-run", response_model=AnalysisRunDetailResponse)
def get_recommendation_analysis_run(
    recommendation_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """The evidence behind one recommendation: model, prompt/policy version, and the
    context snapshot the AI actually saw. Fetched on demand from the expert queue rather
    than embedded in the list response, since this can be a large JSON blob."""
    recommendation = db.query(FieldRecommendation).filter(FieldRecommendation.id == recommendation_id).first()
    if recommendation is None:
        raise APIError(404, "recommendation_not_found", "Recommendation not found.")
    # Same read access as the recommendation itself — owner or staff.
    field_readable_by(db, current_user, recommendation.field_id)

    if recommendation.analysis_run_id is None:
        raise APIError(404, "analysis_run_not_found", "This recommendation has no recorded analysis run.")
    run = db.query(AIAnalysisRun).filter(AIAnalysisRun.id == recommendation.analysis_run_id).first()
    if run is None:
        raise APIError(404, "analysis_run_not_found", "The analysis run behind this recommendation was not found.")
    return run


@router.post("/api/recommendations/{recommendation_id}/expert-validate", response_model=RecommendationResponse)
def expert_validate(
    recommendation_id: UUID,
    validation: RecommendationExpertValidation,
    db: Session = Depends(get_db),
    current_user: User = Depends(RequireRole(["agronomist"])),
):
    from app.models.db_models import Field, UserNotification
    recommendation = db.query(FieldRecommendation).filter(FieldRecommendation.id == recommendation_id).first()
    if recommendation is None:
        raise APIError(404, "recommendation_not_found", "Recommendation not found.")
    # Staff can review any recommendation on a field they can read, not only ones the
    # AI already flagged with requires_expert_confirmation.
    field = field_readable_by(db, current_user, recommendation.field_id)

    recommendation.expert_status = validation.status
    if validation.notes is not None:
        recommendation.expert_notes = validation.notes
    # Audit trail: record who made this call and when, regardless of which way it went —
    # a recommendation that can gate a chemical intervention must have a reviewer of record.
    recommendation.reviewed_by_id = current_user.id
    recommendation.reviewed_at = datetime.now(timezone.utc)

    # Notify the field owner. The reviewer's notes are the substance of the review — they
    # used to be written to the database and never delivered, so the farmer received
    # "an agronomist has approved a recommendation" with none of the reasoning, and only
    # saw the note if they happened to reopen that exact recommendation in the app.
    verdict = "approved" if validation.status == "approved" else "rejected"
    summary = (recommendation.advice or "").strip()
    if len(summary) > 240:
        summary = summary[:237].rstrip() + "..."

    body_parts = [
        f"An agronomist {verdict} the AI recommendation for {field.name}"
        + (f" ({recommendation.category})." if recommendation.category else ".")
    ]
    if summary:
        body_parts.append(f'Advice: "{summary}"')
    notes = (recommendation.expert_notes or "").strip()
    if notes:
        body_parts.append(f"Agronomist's note: {notes}")

    notif = UserNotification(
        user_id=field.owner_id,
        title=(
            f"Expert approved: {field.name}" if verdict == "approved"
            else f"Expert advises against: {field.name}"
        ),
        body="\n\n".join(body_parts),
        # A rejection is a "do not do this" — it needs to stand out at least as much as an
        # approval, so both inherit the recommendation's own priority.
        priority="high" if (recommendation.priority or "").lower() == "high" else "normal",
        category="expert_review",
        field_id=field.id,
        created_by_id=current_user.id,
        reference_id=str(recommendation.id),
        reference_type="recommendation",
    )
    db.add(notif)
        
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

