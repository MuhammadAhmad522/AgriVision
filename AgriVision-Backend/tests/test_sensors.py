from datetime import datetime, timedelta, timezone
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


def test_get_sensor_readings_returns_readings(client):
    user = _mock_user()
    field_id = uuid4()
    sensor_id = uuid4()
    readings = [
        MagicMock(time=datetime.now(timezone.utc), sensor_id=sensor_id, temperature=25.5, moisture=60.0),
    ]
    db = _mock_db()
    query_sensor_id = MagicMock()
    query_sensor_id.filter.return_value.all.return_value = [(sensor_id,)]
    query_reading = MagicMock()
    query_reading.filter.return_value.order_by.return_value.limit.return_value.all.return_value = readings
    db.query = MagicMock(side_effect=[query_sensor_id, query_reading])

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.sensors.owned_field", return_value=MagicMock()):
        response = client.get(f"/api/fields/{field_id}/sensor-readings")

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1


def test_get_sensor_readings_with_no_sensors_returns_empty(client):
    user = _mock_user()
    field_id = uuid4()
    db = _mock_db()
    query = MagicMock()
    query.filter.return_value.all.return_value = []
    db.query.return_value = query

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.sensors.owned_field", return_value=MagicMock()):
        response = client.get(f"/api/fields/{field_id}/sensor-readings")

    assert response.status_code == 200
    assert response.json() == []


def test_verify_sensor_with_valid_online_sensor(client):
    user = _mock_user()
    device_id = "esp32-test-001"
    db = _mock_db()
    sensor = MagicMock()
    sensor.owner_id = None
    sensor.last_seen = datetime.now(timezone.utc)
    sensor.name = "Test Sensor"
    db.query.return_value.filter.return_value.first.return_value = sensor

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    response = client.get(f"/api/sensors/verify/{device_id}")

    assert response.status_code == 200
    assert response.json()["is_verified"] is True


def test_verify_sensor_with_unowned_sensor_returns_409(client):
    user = _mock_user()
    device_id = "esp32-other-tenant"
    db = _mock_db()
    sensor = MagicMock()
    sensor.owner_id = uuid4()
    sensor.last_seen = datetime.now(timezone.utc)
    db.query.return_value.filter.return_value.first.return_value = sensor

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    response = client.get(f"/api/sensors/verify/{device_id}")

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "sensor_owned_by_another_tenant"


def test_verify_sensor_with_invalid_device_id_returns_422(client):
    user = _mock_user()
    device_id = "x" * 101

    app.dependency_overrides[get_db] = lambda: MagicMock()
    app.dependency_overrides[get_current_user] = lambda: user

    response = client.get(f"/api/sensors/verify/{device_id}")

    assert response.status_code == 422


def test_pair_sensor_with_online_unowned_sensor(client):
    user = _mock_user()
    device_id = "esp32-pair-test"
    db = _mock_db()
    sensor = MagicMock()
    sensor.owner_id = None
    sensor.last_seen = datetime.now(timezone.utc)
    sensor.id = uuid4()
    sensor.device_id = device_id
    sensor.name = "Pair Test"
    sensor.sensor_type = "soil"
    sensor.battery_level = None
    sensor.field_id = None
    db.query.return_value.filter.return_value.with_for_update.return_value.first.return_value = sensor

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.sensors.rate_limiter.check"):
        response = client.post("/api/sensors/pair", json={"device_id": device_id})

    assert response.status_code == 200
    assert response.json()["is_paired"] is True
    assert sensor.owner_id == user.id


def test_pair_sensor_owned_by_another_tenant_returns_409(client):
    user = _mock_user()
    device_id = "esp32-other-pair"
    db = _mock_db()
    sensor = MagicMock()
    sensor.owner_id = uuid4()
    sensor.last_seen = datetime.now(timezone.utc)
    db.query.return_value.filter.return_value.with_for_update.return_value.first.return_value = sensor

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.sensors.rate_limiter.check"):
        response = client.post("/api/sensors/pair", json={"device_id": device_id})

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "sensor_owned_by_another_tenant"


def test_pair_sensor_with_offline_sensor_returns_409(client):
    user = _mock_user()
    device_id = "esp32-offline"
    db = _mock_db()
    sensor = MagicMock()
    sensor.owner_id = None
    sensor.last_seen = datetime.now(timezone.utc) - timedelta(hours=2)
    db.query.return_value.filter.return_value.with_for_update.return_value.first.return_value = sensor

    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.sensors.rate_limiter.check"):
        response = client.post("/api/sensors/pair", json={"device_id": device_id})

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "sensor_not_online"
