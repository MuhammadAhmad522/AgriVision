import csv
import io
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


def _make_sensor_row(sensor_id):
    row = MagicMock()
    row.__getitem__ = lambda self, idx: sensor_id if idx == 0 else MagicMock()
    return row


@pytest.fixture(autouse=True)
def _clear_overrides():
    yield
    app.dependency_overrides.clear()


@pytest.fixture
def client():
    return TestClient(app)


def _parse_csv(text: str) -> list[dict]:
    reader = csv.DictReader(io.StringIO(text))
    return list(reader)


def test_export_sensor_readings_raw(client):
    user = _mock_user()
    field_id = uuid4()
    sensor_id = uuid4()
    now = datetime.now(timezone.utc)

    sensor_row = _make_sensor_row(sensor_id)
    reading = MagicMock(
        sensor_id=sensor_id,
        time=now,
        temperature=25.5,
        moisture=60.0,
        humidity=70.0,
        ph=6.5,
        ec=1.2,
        npk_n=10.0,
        npk_p=5.0,
        npk_k=8.0,
    )

    db = _mock_db()
    db.query.return_value.filter.return_value.all.return_value = [sensor_row]
    db.query.return_value.filter.return_value.order_by.return_value.limit.return_value.all.return_value = [reading]
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.export.owned_field"):
        response = client.get(f"/api/fields/{field_id}/export/sensor-readings?granularity=raw")

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/csv")
    assert "attachment" in response.headers["content-disposition"]

    rows = _parse_csv(response.text)
    assert len(rows) == 1
    assert rows[0]["sensor_id"] == str(sensor_id)
    assert rows[0]["temperature"] == "25.5"


def test_export_sensor_readings_hourly(client):
    user = _mock_user()
    field_id = uuid4()
    sensor_id = uuid4()
    now = datetime.now(timezone.utc)

    sensor_row = _make_sensor_row(sensor_id)
    reading = MagicMock(
        sensor_id=sensor_id,
        bucket=now,
        reading_count=10,
        temperature_avg=25.0,
        temperature_min=20.0,
        temperature_max=30.0,
        moisture_avg=60.0,
        moisture_min=50.0,
        moisture_max=70.0,
        humidity_avg=70.0,
        humidity_min=60.0,
        humidity_max=80.0,
        ph_avg=6.5,
        ph_min=6.0,
        ph_max=7.0,
        ec_avg=1.2,
        ec_min=1.0,
        ec_max=1.4,
        npk_n_avg=10.0,
        npk_n_min=8.0,
        npk_n_max=12.0,
        npk_p_avg=5.0,
        npk_p_min=4.0,
        npk_p_max=6.0,
        npk_k_avg=8.0,
        npk_k_min=6.0,
        npk_k_max=10.0,
    )

    db = _mock_db()
    db.query.return_value.filter.return_value.all.return_value = [sensor_row]
    db.query.return_value.filter.return_value.order_by.return_value.limit.return_value.all.return_value = [reading]
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.export.owned_field"):
        response = client.get(f"/api/fields/{field_id}/export/sensor-readings?granularity=hourly")

    assert response.status_code == 200
    rows = _parse_csv(response.text)
    assert len(rows) == 1
    assert rows[0]["reading_count"] == "10"
    assert rows[0]["temperature_avg"] == "25.0"


def test_export_sensor_readings_daily(client):
    user = _mock_user()
    field_id = uuid4()
    sensor_id = uuid4()
    now = datetime.now(timezone.utc)
    bucket = now.replace(hour=0, minute=0, second=0, microsecond=0)

    sensor_row = _make_sensor_row(sensor_id)

    def make_daily_row(data):
        m = MagicMock()
        for k, v in data.items():
            setattr(m, k, v)
        return m

    daily_data = {
        "bucket": bucket,
        "sensor_id": sensor_id,
        "reading_count": 24,
        "temperature_avg": 25.0, "temperature_min": 20.0, "temperature_max": 30.0,
        "moisture_avg": 60.0, "moisture_min": 50.0, "moisture_max": 70.0,
        "humidity_avg": 70.0, "humidity_min": 60.0, "humidity_max": 80.0,
        "ph_avg": 6.5, "ph_min": 6.0, "ph_max": 7.0,
        "ec_avg": 1.2, "ec_min": 1.0, "ec_max": 1.4,
        "npk_n_avg": 10.0, "npk_n_min": 8.0, "npk_n_max": 12.0,
        "npk_p_avg": 5.0, "npk_p_min": 4.0, "npk_p_max": 6.0,
        "npk_k_avg": 8.0, "npk_k_min": 6.0, "npk_k_max": 10.0,
    }
    row = make_daily_row(daily_data)

    db = _mock_db()
    db.query.return_value.filter.return_value.all.return_value = [sensor_row]
    db.query.return_value.filter.return_value.group_by.return_value.order_by.return_value.limit.return_value.all.return_value = [row]
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.export.owned_field"):
        response = client.get(f"/api/fields/{field_id}/export/sensor-readings?granularity=daily")

    assert response.status_code == 200
    rows = _parse_csv(response.text)
    assert len(rows) == 1
    assert rows[0]["reading_count"] == "24"


def test_export_sensor_readings_no_sensors(client):
    user = _mock_user()
    field_id = uuid4()
    db = _mock_db()
    db.query.return_value.filter.return_value.all.return_value = []
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.export.owned_field"):
        response = client.get(f"/api/fields/{field_id}/export/sensor-readings")

    assert response.status_code == 200
    rows = _parse_csv(response.text)
    assert len(rows) == 0


def test_export_recommendations(client):
    user = _mock_user()
    field_id = uuid4()
    rec_id = uuid4()
    now = datetime.now(timezone.utc)

    rec = MagicMock(
        id=rec_id,
        field_id=field_id,
        category="irrigation",
        priority="high",
        advice="Water crops now",
        rationale="Soil moisture is low",
        confidence=0.85,
        confidence_reason="Good data quality",
        safety_level="guarded",
        requires_expert_confirmation=False,
        status="pending",
        ndvi_at_generation=0.65,
        created_at=now,
        expires_at=None,
        outcome=None,
        outcome_notes=None,
        outcome_at=None,
        feedback_at=None,
    )

    db = _mock_db()
    db.query.return_value.filter.return_value.order_by.return_value.limit.return_value.all.return_value = [rec]
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.export.owned_field"):
        response = client.get(f"/api/fields/{field_id}/export/recommendations")

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/csv")
    rows = _parse_csv(response.text)
    assert len(rows) == 1
    assert rows[0]["advice"] == "Water crops now"
    assert rows[0]["category"] == "irrigation"
    assert rows[0]["priority"] == "high"


def test_export_observations(client):
    user = _mock_user()
    field_id = uuid4()
    obs_id = uuid4()
    now = datetime.now(timezone.utc)

    obs = MagicMock(
        id=obs_id,
        source="agromonitoring",
        metric="soil_current",
        value=25.5,
        unit="celsius",
        observed_at=now,
        fetched_at=now,
        expires_at=now,
    )

    db = _mock_db()
    db.query.return_value.filter.return_value.order_by.return_value.limit.return_value.all.return_value = [obs]
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.export.owned_field"):
        response = client.get(f"/api/fields/{field_id}/export/observations")

    assert response.status_code == 200
    rows = _parse_csv(response.text)
    assert len(rows) == 1
    assert rows[0]["source"] == "agromonitoring"
    assert rows[0]["metric"] == "soil_current"


def test_export_satellite_scenes(client):
    user = _mock_user()
    field_id = uuid4()
    scene_id = uuid4()
    now = datetime.now(timezone.utc)

    scene = MagicMock(
        id=scene_id,
        provider_scene_id="S2A_123456",
        provider="agromonitoring",
        source_type="sentinel-2",
        acquired_at=now,
        cloud_percent=15.0,
        coverage_percent=95.0,
        created_at=now,
    )

    db = _mock_db()
    db.query.return_value.filter.return_value.order_by.return_value.limit.return_value.all.return_value = [scene]
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.export.owned_field"):
        response = client.get(f"/api/fields/{field_id}/export/satellite-scenes")

    assert response.status_code == 200
    rows = _parse_csv(response.text)
    assert len(rows) == 1
    assert rows[0]["provider_scene_id"] == "S2A_123456"
    assert rows[0]["cloud_percent"] == "15.0"


def test_export_chat(client):
    user = _mock_user()
    field_id = uuid4()
    msg_id = uuid4()
    now = datetime.now(timezone.utc)

    msg = MagicMock(
        id=msg_id,
        role="user",
        content="What should I plant?",
        status="completed",
        created_at=now,
    )

    db = _mock_db()
    db.query.return_value.filter.return_value.order_by.return_value.limit.return_value.all.return_value = [msg]
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.export.owned_field"):
        response = client.get(f"/api/fields/{field_id}/export/chat")

    assert response.status_code == 200
    rows = _parse_csv(response.text)
    assert len(rows) == 1
    assert rows[0]["role"] == "user"
    assert rows[0]["content"] == "What should I plant?"


def test_export_empty_results(client):
    user = _mock_user()
    field_id = uuid4()
    db = _mock_db()
    db.query.return_value.filter.return_value.order_by.return_value.limit.return_value.all.return_value = []
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user

    with patch("app.api.export.owned_field"):
        for endpoint in ["recommendations", "observations", "satellite-scenes", "chat"]:
            response = client.get(f"/api/fields/{field_id}/export/{endpoint}")
            assert response.status_code == 200
            rows = _parse_csv(response.text)
            assert len(rows) == 0, f"{endpoint} should return empty CSV"
