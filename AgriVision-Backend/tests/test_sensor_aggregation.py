import asyncio
import uuid
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text

from app.core.auth import get_current_user
from app.database import SessionLocal
from app.main import app
from app.models.db_models import Field, Sensor, SensorReading, SensorReadingHourly, User


@pytest.fixture(autouse=True)
def _clean():
    yield
    db = SessionLocal()
    try:
        for t in ("sensor_readings_hourly", "sensor_readings", "sensors", "fields", "users"):
            db.execute(text(f"DELETE FROM {t}"))
        db.commit()
    finally:
        db.close()


def _seed_sensor_data():
    db = SessionLocal()
    try:
        uid = uuid.uuid4().hex
        user = User(firebase_uid=uid, email=f"{uid}@test.ag")
        db.add(user)
        db.flush()
        field = Field(
            id=uuid.uuid4(), owner_id=user.id, name="Aggr Field",
            boundary="POLYGON((0 0, 1 0, 1 1, 0 1, 0 0))", area_ha=2.0,
            status="active", agro_status="pending", crop_type="Wheat",
        )
        db.add(field)
        db.flush()
        sensor = Sensor(device_id=f"ESP32_{uuid.uuid4().hex[:8]}", sensor_type="multi_sensor", field_id=field.id, owner_id=user.id)
        db.add(sensor)
        db.flush()
        now = datetime.now(timezone.utc).replace(minute=0, second=0, microsecond=0)
        for hour_offset in range(5):
            t = now - timedelta(hours=hour_offset)
            for _ in range(3):
                db.add(SensorReading(
                    sensor_id=sensor.id, time=t + timedelta(minutes=10 * _),
                    temperature=25.0 + hour_offset, moisture=0.3 + hour_offset * 0.01,
                ))
        db.commit()
        db.commit()
        return db, user, field, sensor
    except Exception:
        db.close()
        raise


class TestAggregation:
    def test_hourly_bucket_creation(self):
        db, user, field, sensor = _seed_sensor_data()
        try:
            from app.services.scheduler import _aggregate_sensor_readings
            _aggregate_sensor_readings()

            buckets = db.query(SensorReadingHourly).filter(
                SensorReadingHourly.sensor_id == sensor.id
            ).order_by(SensorReadingHourly.bucket.asc()).all()
            assert len(buckets) == 4  # current incomplete hour excluded
            for bucket in buckets:
                assert bucket.reading_count == 3
                assert bucket.temperature_min <= bucket.temperature_avg + 1e-9
                assert bucket.temperature_avg <= bucket.temperature_max + 1e-9
                assert bucket.moisture_min - 1e-9 <= bucket.moisture_avg
                assert bucket.moisture_avg <= bucket.moisture_max + 1e-9
        finally:
            db.close()

    def test_idempotent_aggregation(self):
        db, user, field, sensor = _seed_sensor_data()
        try:
            from app.services.scheduler import _aggregate_sensor_readings
            _aggregate_sensor_readings()
            count1 = db.query(SensorReadingHourly).count()
            _aggregate_sensor_readings()
            count2 = db.query(SensorReadingHourly).count()
            assert count1 == count2
        finally:
            db.close()

    def test_raw_readings_purge(self):
        db, user, field, sensor = _seed_sensor_data()
        try:
            old_time = datetime.now(timezone.utc) - timedelta(days=20)
            db.add(SensorReading(sensor_id=sensor.id, time=old_time, temperature=10.0))
            db.commit()
            assert db.query(SensorReading).count() == 16  # 15 from seed + 1 old
            from app.services.scheduler import _aggregate_sensor_readings, _purge_raw_readings
            _purge_raw_readings()
            remaining = db.query(SensorReading).count()
            assert remaining == 15  # old one gone
        finally:
            db.close()


class TestSensorReadingsEndpoint:
    @pytest.fixture(autouse=True)
    def _setup(self):
        _noop_task = lambda: asyncio.ensure_future(asyncio.sleep(0))
        _noop_coro = lambda: asyncio.sleep(0)
        async def _null_async():
            return _noop_task()
        with (
            patch("app.main._prepare_database"),
            patch("app.main._initialize_firebase"),
            patch("app.main.start_background_tasks", side_effect=_null_async),
            patch("app.services.scheduler.start_ai_reasoning_worker", side_effect=_noop_task),
            patch("app.services.scheduler.start_satellite_sync_worker", side_effect=_noop_task),
            patch("app.services.scheduler._aggregation_loop", side_effect=_noop_coro),
        ):
            db, user, field, sensor = _seed_sensor_data()
            self._test_user = user
            self._test_field = field
            self._test_sensor = sensor
            yield
            db.close()

    @contextmanager
    def _client_with_auth(self):
        app.dependency_overrides[get_current_user] = lambda: self._test_user
        with TestClient(app) as client:
            yield client
        app.dependency_overrides.pop(get_current_user, None)

    def test_raw_granularity_returns_readings(self):
        from app.services.scheduler import _aggregate_sensor_readings
        _aggregate_sensor_readings()
        with self._client_with_auth() as client:
            resp = client.get(f"/api/fields/{self._test_field.id}/sensor-readings?granularity=raw&limit=50")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 15
        assert "temperature" in data[0]
        assert "moisture" in data[0]

    def test_hourly_granularity_returns_aggregates(self):
        from app.services.scheduler import _aggregate_sensor_readings
        _aggregate_sensor_readings()
        with self._client_with_auth() as client:
            resp = client.get(f"/api/fields/{self._test_field.id}/sensor-readings?granularity=hourly&limit=50")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 4  # current incomplete hour excluded
        assert "temperature_avg" in data[0]
        assert "temperature_min" in data[0]
        assert "reading_count" in data[0]

    def test_daily_granularity_returns_daily_buckets(self):
        from app.services.scheduler import _aggregate_sensor_readings
        _aggregate_sensor_readings()
        with self._client_with_auth() as client:
            resp = client.get(f"/api/fields/{self._test_field.id}/sensor-readings?granularity=daily&limit=10")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) >= 1
        assert "temperature_avg" in data[0]

    def test_invalid_granularity_rejected(self):
        with self._client_with_auth() as client:
            resp = client.get(f"/api/fields/{self._test_field.id}/sensor-readings?granularity=weekly")
        assert resp.status_code == 422
