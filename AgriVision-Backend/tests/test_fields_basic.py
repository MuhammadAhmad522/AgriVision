from datetime import datetime, timezone
from unittest.mock import MagicMock, patch
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.database import get_db
from app.main import app
from app.schemas.pydantic_schemas import FieldIntervalOverrides, FieldResponse


def _mock_user():
    user = MagicMock()
    user.id = uuid4()
    user.firebase_uid = f"test-{uuid4()}"
    return user


def _mock_db():
    return MagicMock()


def _make_field_response(field_id, user_id, name="Test Field"):
    now = datetime.now(timezone.utc)
    return FieldResponse(
        id=field_id,
        owner_id=user_id,
        name=name,
        coordinates=[],
        area_ha=10.5,
        status="active",
        created_at=now,
        updated_at=now,
        crop_type="Rice",
    )


@pytest.fixture(autouse=True)
def _clear_overrides():
    yield
    app.dependency_overrides.clear()


@pytest.fixture
def client():
    return TestClient(app)


def test_get_fields_returns_list(client):
    user = _mock_user()
    db = _mock_db()
    field1 = MagicMock()
    field1.id = uuid4()
    field2 = MagicMock()
    field2.id = uuid4()
    fields = [field1, field2]

    query = MagicMock()
    query.filter.return_value = query
    query.order_by.return_value = query
    query.all.return_value = fields
    db.query.return_value = query

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.fields.field_to_response") as mock_ftr:
        mock_ftr.side_effect = lambda f, _: _make_field_response(f.id, user.id)
        response = client.get("/api/fields")

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2


def test_get_fields_with_include_archived(client):
    user = _mock_user()
    db = _mock_db()
    field1 = MagicMock()
    field1.id = uuid4()
    archived = MagicMock()
    archived.id = uuid4()
    fields = [field1, archived]

    query = MagicMock()
    query.filter.return_value = query
    query.order_by.return_value = query
    query.all.return_value = fields
    db.query.return_value = query

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.fields.field_to_response") as mock_ftr:
        mock_ftr.side_effect = lambda f, _: _make_field_response(f.id, user.id)
        response = client.get("/api/fields?include_archived=true")

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2


def test_update_field_name(client):
    user = _mock_user()
    db = _mock_db()
    field_id = uuid4()
    field = MagicMock()
    field.id = field_id
    field.name = "Original Name"
    field.owner_id = user.id
    field.plantation_date = None
    field.expected_harvest_date = None

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.fields.owned_field", return_value=field):
        with patch("app.api.fields.field_to_response") as mock_ftr:
            mock_ftr.return_value = _make_field_response(field_id, user.id, "New Name")
            response = client.patch(f"/api/fields/{field_id}", json={"name": "New Name"})

    assert response.status_code == 200
    assert field.name == "New Name"


def test_update_field_with_invalid_harvest_date(client):
    user = _mock_user()
    db = _mock_db()
    field_id = uuid4()
    field = MagicMock()
    field.id = field_id
    field.owner_id = user.id
    field.plantation_date = datetime(2024, 6, 1, tzinfo=timezone.utc)
    field.expected_harvest_date = datetime(2024, 6, 15, tzinfo=timezone.utc)

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.fields.owned_field", return_value=field):
        response = client.patch(
            f"/api/fields/{field_id}",
            json={"expected_harvest_date": "2024-01-01T00:00:00Z"},
        )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "invalid_harvest_date"


def test_data_refresh_with_api_key_configured(client):
    user = _mock_user()
    db = _mock_db()
    field_id = uuid4()
    field = MagicMock()
    field.id = field_id
    field.owner_id = user.id
    
    field.name = "Updated by sync"
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.fields.owned_field", return_value=field):
        with patch("app.api.fields.settings.AGROMONITORING_API_KEY", "test-key"):
            with patch("app.api.fields.rate_limiter.check"):
                with patch("app.api.fields._sync_field_background"):
                    response = client.post(f"/api/fields/{field_id}/data-refresh")

    assert response.status_code == 202
    assert response.json()["status"] == "accepted"


def test_data_refresh_without_api_key(client):
    user = _mock_user()
    db = _mock_db()
    field_id = uuid4()
    field = MagicMock()
    field.id = field_id
    field.owner_id = user.id

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.fields.owned_field", return_value=field):
        with patch("app.api.fields.settings.AGROMONITORING_API_KEY", ""):
            response = client.post(f"/api/fields/{field_id}/data-refresh")

    assert response.status_code == 503
    assert response.json()["error"]["code"] == "agromonitoring_not_configured"


def test_update_field_with_interval_overrides(client):
    user = _mock_user()
    db = _mock_db()
    field_id = uuid4()
    field = MagicMock()
    field.id = field_id
    field.owner_id = user.id
    field.name = "Test Field"
    field.plantation_date = None
    field.expected_harvest_date = None
    field.interval_overrides = {}

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.fields.owned_field", return_value=field):
        with patch("app.api.fields.field_to_response") as mock_ftr:
            resp = _make_field_response(field_id, user.id)
            resp.interval_overrides = {"weather_hours": 3, "ai_hours": 2}
            mock_ftr.return_value = resp
            response = client.patch(
                f"/api/fields/{field_id}",
                json={"interval_overrides": {"weather_hours": 3, "ai_hours": 2}},
            )

    assert response.status_code == 200
    data = response.json()
    assert data["interval_overrides"] == {"weather_hours": 3, "ai_hours": 2}
    assert field.interval_overrides == {"weather_hours": 3, "ai_hours": 2}


def test_update_field_interval_overrides_partial(client):
    user = _mock_user()
    db = _mock_db()
    field_id = uuid4()
    field = MagicMock()
    field.id = field_id
    field.owner_id = user.id
    field.name = "Test Field"
    field.plantation_date = None
    field.expected_harvest_date = None
    field.interval_overrides = {}

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.fields.owned_field", return_value=field):
        with patch("app.api.fields.field_to_response") as mock_ftr:
            resp = _make_field_response(field_id, user.id)
            resp.interval_overrides = {"satellite_hours": 12}
            mock_ftr.return_value = resp
            response = client.patch(
                f"/api/fields/{field_id}",
                json={"interval_overrides": {"satellite_hours": 12}},
            )

    assert response.status_code == 200
    assert field.interval_overrides == {"satellite_hours": 12}


def test_field_interval_overrides_pydantic_rejects_out_of_range():
    with pytest.raises(Exception):
        FieldIntervalOverrides(weather_hours=999)


def test_field_interval_overrides_pydantic_rejects_negative():
    with pytest.raises(Exception):
        FieldIntervalOverrides(retention_days=-1)


def test_field_interval_overrides_pydantic_valid():
    overrides = FieldIntervalOverrides(weather_hours=3, ai_hours=2, retention_days=30)
    assert overrides.weather_hours == 3
    assert overrides.ai_hours == 2
    assert overrides.retention_days == 30
    assert overrides.soil_hours is None


def test_field_interval_overrides_pydantic_defaults():
    overrides = FieldIntervalOverrides()
    assert overrides.weather_hours is None
    assert overrides.soil_hours is None
    assert overrides.uvi_hours is None
    assert overrides.satellite_hours is None
    assert overrides.ai_hours is None
    assert overrides.retention_days is None
