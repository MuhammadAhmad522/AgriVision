from datetime import datetime, timezone
from unittest.mock import MagicMock, patch
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.core.config import settings
from app.database import get_db
from app.main import app
from app.schemas.pydantic_schemas import FieldResponse


def _mock_user():
    user = MagicMock()
    user.id = uuid4()
    user.firebase_uid = f"test-{uuid4()}"
    user.email = "test@example.com"
    user.role = "mobile_user"
    user.created_at = datetime.now(timezone.utc)
    return user


def _mock_db():
    return MagicMock()


def _make_field_response(field_id, name, owner_id):
    now = datetime.now(timezone.utc)
    return FieldResponse(
        id=field_id,
        owner_id=owner_id,
        name=name,
        coordinates=[],
        area_ha=0.0,
        status="active",
        created_at=now,
        updated_at=now,
        crop_type="Barley",
    )


@pytest.fixture(autouse=True)
def _clear_overrides():
    yield
    app.dependency_overrides.clear()


@pytest.fixture
def client():
    return TestClient(app)


class TestSessionBootstrap:
    def test_bootstrap_returns_user_info_and_fields(self, client):
        user = _mock_user()
        db = _mock_db()

        field_ids = [uuid4(), uuid4()]
        fields = [
            MagicMock(id=field_ids[0], name="Field A", owner_id=user.id),
            MagicMock(id=field_ids[1], name="Field B", owner_id=user.id),
        ]
        query = MagicMock()
        query.filter.return_value.order_by.return_value.all.return_value = fields
        # bootstrap() also queries Invitation for a pending role upgrade — keep that branch inert.
        query.filter.return_value.first.return_value = None
        db.query.return_value = query

        app.dependency_overrides[get_db] = lambda: db
        app.dependency_overrides[get_current_user] = lambda: user

        mock_field_responses = [
            _make_field_response(field_ids[0], "Field A", user.id),
            _make_field_response(field_ids[1], "Field B", user.id),
        ]

        with patch(
            "app.api.session.field_to_response",
            side_effect=mock_field_responses,
        ):
            response = client.post("/api/session/bootstrap")

        assert response.status_code == 200
        data = response.json()
        assert data["user"]["id"] == str(user.id)
        assert data["user"]["firebase_uid"] == user.firebase_uid
        assert len(data["fields"]) == 2
        assert data["fields"][0]["id"] == str(field_ids[0])
        assert data["fields"][1]["id"] == str(field_ids[1])
        assert data["active_field_limit"] == settings.ACTIVE_FIELD_LIMIT
        assert data["active_field_count"] == 2

    def test_bootstrap_with_zero_fields(self, client):
        user = _mock_user()
        db = _mock_db()

        query = MagicMock()
        query.filter.return_value.order_by.return_value.all.return_value = []
        query.filter.return_value.first.return_value = None
        db.query.return_value = query

        app.dependency_overrides[get_db] = lambda: db
        app.dependency_overrides[get_current_user] = lambda: user

        with patch("app.api.session.field_to_response", return_value=MagicMock()):
            response = client.post("/api/session/bootstrap")

        assert response.status_code == 200
        data = response.json()
        assert data["user"]["id"] == str(user.id)
        assert data["user"]["firebase_uid"] == user.firebase_uid
        assert data["fields"] == []
        assert data["active_field_limit"] == settings.ACTIVE_FIELD_LIMIT
        assert data["active_field_count"] == 0
