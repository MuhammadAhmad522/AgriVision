import uuid
from datetime import datetime, timezone, timedelta
import pytest
from pydantic import ValidationError
from sqlalchemy import text

from app.database import SessionLocal
from app.models.db_models import User, UserRole, Field, Sensor, SensorReading, SensorReadingHourly
from app.schemas.pydantic_schemas import AISettingsUpdate
from app.services.mqtt_service import _write_batch
from app.services.scheduler import _aggregate_sensor_readings, _purge_raw_readings


@pytest.fixture
def clean_db():
    def do_delete():
        db = SessionLocal()
        try:
            for t in ("sensor_readings_hourly", "sensor_readings", "sensors", "fields", "invitations", "users"):
                db.execute(text(f"DELETE FROM {t}"))
            db.commit()
        except Exception:
            db.rollback()
        finally:
            db.close()

    do_delete()
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
        do_delete()


def test_battery_telemetry_and_last_seen_tracking(clean_db):
    user = User(id=uuid.uuid4(), email="telemetry@test.com", firebase_uid="fb-telemetry")
    clean_db.add(user)
    clean_db.flush()

    sensor = Sensor(device_id="ESP32_BATTERY_TEST", sensor_type="multi_sensor", owner_id=user.id)
    clean_db.add(sensor)
    clean_db.commit()

    now = datetime.now(timezone.utc)
    item = {
        "device_id": "ESP32_BATTERY_TEST",
        "timestamp": now,
        "values": {"temperature": 24.5, "humidity": 60.0},
        "battery_level": 87.5,
    }

    _write_batch([item])

    clean_db.refresh(sensor)
    assert sensor.battery_level == 87.5
    assert sensor.last_seen is not None

    reading = clean_db.query(SensorReading).filter_by(sensor_id=sensor.id).first()
    assert reading is not None
    assert reading.temperature == 24.5


def test_empty_probe_suppression_with_heartbeat(clean_db):
    user = User(id=uuid.uuid4(), email="heartbeat@test.com", firebase_uid="fb-heartbeat")
    clean_db.add(user)
    clean_db.flush()

    sensor = Sensor(device_id="ESP32_HEARTBEAT_TEST", sensor_type="multi_sensor", owner_id=user.id)
    clean_db.add(sensor)
    clean_db.commit()

    now = datetime.now(timezone.utc)
    item = {
        "device_id": "ESP32_HEARTBEAT_TEST",
        "timestamp": now,
        "values": None,
        "battery_level": 92.0,
    }

    _write_batch([item])

    clean_db.refresh(sensor)
    assert sensor.battery_level == 92.0
    assert sensor.last_seen is not None

    # No empty probe row should be created
    reading_count = clean_db.query(SensorReading).filter_by(sensor_id=sensor.id).count()
    assert reading_count == 0


def test_unassigned_sensor_purge(clean_db):
    user = User(id=uuid.uuid4(), email="unassigned@test.com", firebase_uid="fb-unassigned")
    clean_db.add(user)
    clean_db.flush()

    # Sensor with no field_id assigned
    sensor = Sensor(device_id="ESP32_ORPHAN", sensor_type="multi_sensor", owner_id=user.id, field_id=None)
    clean_db.add(sensor)
    clean_db.flush()

    # Old reading (20 days ago) and recent reading (2 days ago)
    old_time = datetime.now(timezone.utc) - timedelta(days=20)
    recent_time = datetime.now(timezone.utc) - timedelta(days=2)

    clean_db.add_all([
        SensorReading(sensor_id=sensor.id, time=old_time, temperature=21.0),
        SensorReading(sensor_id=sensor.id, time=recent_time, temperature=22.0),
    ])
    clean_db.commit()

    assert clean_db.query(SensorReading).filter_by(sensor_id=sensor.id).count() == 2

    # Run purge
    _purge_raw_readings()

    clean_db.expire_all()
    # Old reading should be purged (default 14 days for unassigned sensors), recent kept
    remaining = clean_db.query(SensorReading).filter_by(sensor_id=sensor.id).all()
    assert len(remaining) == 1
    assert remaining[0].time == recent_time


def test_ai_settings_update_validation():
    # Valid
    valid = AISettingsUpdate(mode="paid", model="gemini-2.5-flash")
    assert valid.mode == "paid"
    assert valid.model == "gemini-2.5-flash"

    # Invalid mode
    with pytest.raises(ValidationError):
        AISettingsUpdate(mode="unsupported_provider", model="gemini-2.5-flash")

    # Invalid model length
    with pytest.raises(ValidationError):
        AISettingsUpdate(mode="paid", model="")

