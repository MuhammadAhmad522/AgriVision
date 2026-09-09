from unittest.mock import MagicMock, patch
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.core.errors import APIError
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


SIMPLE_COORDINATES = [
    {"longitude": 0.0, "latitude": 0.0},
    {"longitude": 0.001, "latitude": 0.0},
    {"longitude": 0.001, "latitude": 0.001},
    {"longitude": 0.0, "latitude": 0.001},
]

BOWTIE_COORDINATES = [
    {"longitude": 0.0, "latitude": 0.0},
    {"longitude": 1.0, "latitude": 1.0},
    {"longitude": 1.0, "latitude": 0.0},
    {"longitude": 0.0, "latitude": 1.0},
]


def test_creation_with_self_intersecting_boundary(client):
    user = _mock_user()
    db = _mock_db()

    db.query.return_value.filter.return_value.scalar.return_value = 0
    db.execute.return_value.scalar.side_effect = [False]

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.fields.rate_limiter.check"):
        response = client.post("/api/fields", json={
            "name": "Self-Intersecting Field",
            "coordinates": BOWTIE_COORDINATES,
        })

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "invalid_boundary"


def test_creation_with_field_area_less_than_one_hectare(client):
    user = _mock_user()
    db = _mock_db()

    db.query.return_value.filter.return_value.scalar.return_value = 0
    db.execute.return_value.scalar.side_effect = [True, 0.5]

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.fields.rate_limiter.check"):
        response = client.post("/api/fields", json={
            "name": "Tiny Field",
            "coordinates": SIMPLE_COORDINATES,
        })

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "field_area_out_of_range"


def test_creation_when_at_active_field_limit(client):
    user = _mock_user()
    db = _mock_db()

    db.query.return_value.filter.return_value.scalar.return_value = 5

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.fields.rate_limiter.check"):
        response = client.post("/api/fields", json={
            "name": "Over Limit Field",
            "coordinates": SIMPLE_COORDINATES,
        })

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "active_field_limit"


def test_creation_with_invalid_wkt_polygon(client):
    user = _mock_user()
    db = _mock_db()

    db.query.return_value.filter.return_value.scalar.return_value = 0
    db.execute.return_value.scalar.side_effect = [False]

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.fields.rate_limiter.check"):
        response = client.post("/api/fields", json={
            "name": "Invalid WKT Field",
            "coordinates": SIMPLE_COORDINATES,
        })

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "invalid_boundary"
