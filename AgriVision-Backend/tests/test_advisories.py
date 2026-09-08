"""Staff-to-farmer advisories.

These cover the channel that did not exist: an agronomist had no way to send a farmer
anything, and the one automatic notification the platform did emit discarded the reviewer's
notes — the substance of the review — before delivery.
"""

from datetime import datetime, timezone
from unittest.mock import MagicMock, patch
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.database import get_db
from app.main import app


def _mock_user(role="agronomist"):
    user = MagicMock()
    user.id = uuid4()
    user.role = role
    user.email = f"{role}@example.com"
    user.firebase_uid = f"test-{uuid4()}"
    return user


def _mock_field(owner_id, name="North Block"):
    field = MagicMock()
    field.id = uuid4()
    field.owner_id = owner_id
    field.name = name
    return field


def _mock_recommendation(field_id, *, advice, category, priority):
    """A recommendation shaped to satisfy RecommendationResponse.

    Left as a bare MagicMock, every unset attribute serialises as a mock and Pydantic
    rejects the whole response — which surfaces as a confusing 500 rather than the
    behaviour under test.
    """
    recommendation = MagicMock()
    recommendation.id = uuid4()
    recommendation.field_id = field_id
    recommendation.category = category
    recommendation.priority = priority
    recommendation.advice = advice
    recommendation.rationale = None
    recommendation.confidence = None
    recommendation.confidence_reason = None
    recommendation.evidence = None
    recommendation.safety_level = "guarded"
    recommendation.requires_expert_confirmation = True
    recommendation.expert_status = "pending"
    recommendation.expert_notes = None
    recommendation.status = "pending"
    recommendation.ndvi_at_generation = None
    recommendation.created_at = datetime.now(timezone.utc)
    recommendation.expires_at = None
    recommendation.outcome = None
    recommendation.outcome_notes = None
    recommendation.analysis_run_id = None
    recommendation.reviewed_by_id = None
    recommendation.reviewed_by_email = None
    recommendation.reviewed_at = None
    return recommendation


@pytest.fixture(autouse=True)
def _clear_overrides():
    yield
    app.dependency_overrides.clear()


@pytest.fixture
def client():
    return TestClient(app)


def test_send_advisory_creates_notification_for_the_field_owner(client):
    staff = _mock_user("agronomist")
    farmer_id = uuid4()
    field = _mock_field(farmer_id)
    db = MagicMock()

    added = []
    db.add.side_effect = added.append

    def _refresh(obj):
        obj.id = uuid4()
        obj.is_read = False
        obj.created_at = datetime.now(timezone.utc)
        # field_name / created_by_email are read-only properties resolved through these
        # relationships, so they are populated by attaching the related rows.
        obj.field = field
        obj.created_by = staff

    db.refresh.side_effect = _refresh

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: staff

    with patch("app.api.advisories.field_readable_by", return_value=field), \
         patch("app.api.advisories.rate_limiter.check"):
        response = client.post(
            f"/api/fields/{field.id}/advisories",
            json={
                "title": "Irrigate before Thursday",
                "message": "Soil moisture has dropped below the level I am comfortable with.",
                "priority": "high",
            },
        )

    assert response.status_code == 201, response.text
    body = response.json()
    assert body["priority"] == "high"
    assert body["category"] == "expert_advisory"

    # The notification must be addressed to the farmer who owns the field, not to the
    # agronomist who sent it.
    assert len(added) == 1
    notification = added[0]
    assert notification.user_id == farmer_id
    assert notification.created_by_id == staff.id
    assert notification.field_id == field.id
    assert "Soil moisture" in notification.body


def test_send_advisory_is_rejected_for_non_staff(client):
    farmer = _mock_user("mobile_user")
    field = _mock_field(farmer.id)

    app.dependency_overrides[get_db] = lambda: MagicMock()
    app.dependency_overrides[get_current_user] = lambda: farmer

    response = client.post(
        f"/api/fields/{field.id}/advisories",
        json={"title": "Anything", "message": "Farmers cannot advise themselves here."},
    )

    assert response.status_code == 403


@pytest.mark.parametrize(
    "payload",
    [
        {"title": "ok", "message": "Too short a title."},          # title under 3 chars
        {"title": "Valid title", "message": "x"},                   # message under 3 chars
        {"title": "Valid title", "message": "Fine", "priority": "catastrophic"},
    ],
)
def test_send_advisory_rejects_invalid_payloads(client, payload):
    staff = _mock_user("agronomist")
    field = _mock_field(uuid4())

    app.dependency_overrides[get_db] = lambda: MagicMock()
    app.dependency_overrides[get_current_user] = lambda: staff

    with patch("app.api.advisories.field_readable_by", return_value=field), \
         patch("app.api.advisories.rate_limiter.check"):
        response = client.post(f"/api/fields/{field.id}/advisories", json=payload)

    assert response.status_code == 422


def test_expert_validation_delivers_the_reviewers_notes_to_the_farmer(client):
    """The regression this guards.

    `expert-validate` used to send "An agronomist has approved a recommendation for X."
    and drop `notes` entirely, so the farmer got a verdict with none of the reasoning
    behind it — while the UI's own textarea promised "Add notes for the farmer".
    """
    staff = _mock_user("agronomist")
    farmer_id = uuid4()
    field = _mock_field(farmer_id, name="South Cotton")

    recommendation = _mock_recommendation(
        field.id,
        advice="Apply 40mm of irrigation within 24 hours.",
        category="irrigation",
        priority="high",
    )

    db = MagicMock()
    db.query.return_value.filter.return_value.first.return_value = recommendation
    added = []
    db.add.side_effect = added.append

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: staff

    notes = "Agreed, but split it across two passes so it does not run off the slope."
    with patch("app.api.recommendations.field_readable_by", return_value=field):
        response = client.post(
            f"/api/recommendations/{recommendation.id}/expert-validate",
            json={"status": "approved", "notes": notes},
        )

    assert response.status_code == 200, response.text

    assert len(added) == 1
    notification = added[0]
    assert notification.user_id == farmer_id
    assert notification.created_by_id == staff.id
    assert notification.field_id == field.id
    # The reviewer's own words reach the farmer, alongside the advice being ruled on.
    assert notes in notification.body
    assert "Apply 40mm of irrigation" in notification.body
    assert "South Cotton" in notification.title
    # A high-priority recommendation's review inherits that urgency.
    assert notification.priority == "high"


def test_expert_rejection_is_delivered_and_reads_as_a_warning(client):
    staff = _mock_user("agronomist")
    farmer_id = uuid4()
    field = _mock_field(farmer_id, name="East Wheat")

    recommendation = _mock_recommendation(
        field.id,
        advice="Apply fungicide immediately.",
        category="plant_health",
        priority="medium",
    )

    db = MagicMock()
    db.query.return_value.filter.return_value.first.return_value = recommendation
    added = []
    db.add.side_effect = added.append

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: staff

    with patch("app.api.recommendations.field_readable_by", return_value=field):
        response = client.post(
            f"/api/recommendations/{recommendation.id}/expert-validate",
            json={"status": "rejected", "notes": "That is leaf scorch, not disease. Do not spray."},
        )

    assert response.status_code == 200, response.text
    notification = added[0]
    # A "do not do this" must not be titled as an approval.
    assert "advises against" in notification.title
    assert "Do not spray" in notification.body
