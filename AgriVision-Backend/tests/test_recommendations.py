from datetime import datetime, timezone
from unittest.mock import MagicMock, patch
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.database import get_db
from app.main import app


def _mock_user():
    user = MagicMock()
    user.id = uuid4()
    user.firebase_uid = f"test-{uuid4()}"
    return user


def _mock_db():
    return MagicMock()


@pytest.fixture(autouse=True)
def _clear_overrides():
    yield
    app.dependency_overrides.clear()


@pytest.fixture
def client():
    return TestClient(app)


def test_get_recommendations_returns_list(client):
    user = _mock_user()
    field_id = uuid4()
    recommendations = [
        _make_recommendation(field_id=field_id, advice="Water now"),
    ]
    db = _mock_db()
    query = MagicMock()
    query.filter.return_value.order_by.return_value.limit.return_value.all.return_value = recommendations
    db.query.return_value = query

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.recommendations.owned_field", return_value=MagicMock()):
        response = client.get(f"/api/fields/{field_id}/recommendations")

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["advice"] == "Water now"


def _make_recommendation(**overrides):
    now = datetime.now(timezone.utc)
    defaults = dict(
        id=uuid4(), field_id=uuid4(), category="irrigation", priority="high",
        advice="Water now", rationale=None, confidence=None,
        confidence_reason=None, evidence=None, safety_level="guarded",
        requires_expert_confirmation=False, status="pending",
        ndvi_at_generation=None, created_at=now, expires_at=None,
        outcome=None, outcome_notes=None,
    )
    defaults.update(overrides)
    return MagicMock(**defaults)


def test_feedback_with_valid_status(client):
    user = _mock_user()
    recommendation_id = uuid4()
    rec = _make_recommendation(id=recommendation_id, status="pending")
    db = _mock_db()
    db.query.return_value.filter.return_value.first.return_value = rec

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.recommendations.owned_field", return_value=MagicMock()):
        response = client.post(
            f"/api/recommendations/{recommendation_id}/feedback",
            json={"status": "implemented"},
        )

    assert response.status_code == 200
    assert rec.status == "implemented"
    assert rec.feedback_at is not None


def test_feedback_with_nonexistent_recommendation(client):
    user = _mock_user()
    recommendation_id = uuid4()
    db = _mock_db()
    db.query.return_value.filter.return_value.first.return_value = None

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    response = client.post(
        f"/api/recommendations/{recommendation_id}/feedback",
        json={"status": "implemented"},
    )

    assert response.status_code == 404
    data = response.json()
    assert data["error"]["code"] == "recommendation_not_found"


def test_outcome_with_valid_implemented_recommendation(client):
    user = _mock_user()
    recommendation_id = uuid4()
    rec = _make_recommendation(id=recommendation_id, status="implemented")
    db = _mock_db()
    db.query.return_value.filter.return_value.first.return_value = rec

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.recommendations.owned_field", return_value=MagicMock()):
        response = client.post(
            f"/api/recommendations/{recommendation_id}/outcome",
            json={"outcome": "useful", "notes": "Helped"},
        )

    assert response.status_code == 200
    assert rec.outcome == "useful"
    assert rec.outcome_notes == "Helped"


def test_outcome_with_pending_recommendation(client):
    user = _mock_user()
    recommendation_id = uuid4()
    rec = _make_recommendation(id=recommendation_id, status="pending")
    db = _mock_db()
    db.query.return_value.filter.return_value.first.return_value = rec

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.recommendations.owned_field", return_value=MagicMock()):
        response = client.post(
            f"/api/recommendations/{recommendation_id}/outcome",
            json={"outcome": "useful", "notes": "Helped"},
        )

    assert response.status_code == 409
    data = response.json()
    assert data["error"]["code"] == "recommendation_not_implemented"


def test_trigger_refresh(client):
    user = _mock_user()
    field_id = uuid4()
    db = _mock_db()

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.recommendations.owned_field", return_value=MagicMock()):
        with patch("app.api.recommendations.rate_limiter.check"):
            with patch("app.api.recommendations._run_ai_background"):
                response = client.post(f"/api/fields/{field_id}/recommendations")

    assert response.status_code == 202
