import json
import uuid
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from sqlalchemy import text
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.ext.compiler import compiles

from app.database import SessionLocal, engine
from app.models.db_models import Field, SatelliteScene, User


@compiles(JSONB, "sqlite")
def _jsonb_sqlite(type_, compiler, **kw):
    return "TEXT"


@compiles(PG_UUID, "sqlite")
def _uuid_sqlite(type_, compiler, **kw):
    return "TEXT"


_CREATE_TABLES = """
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY, firebase_uid TEXT NOT NULL, email TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE TABLE IF NOT EXISTS fields (
    id TEXT PRIMARY KEY, owner_id TEXT NOT NULL REFERENCES users(id),
    name TEXT NOT NULL, crop_type TEXT, plantation_date TIMESTAMP,
    expected_harvest_date TIMESTAMP, boundary TEXT, area_ha REAL NOT NULL,
    status TEXT NOT NULL DEFAULT 'active', archived_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    latest_ndvi REAL
);
CREATE TABLE IF NOT EXISTS field_provider_links (
    id TEXT PRIMARY KEY, field_id TEXT NOT NULL REFERENCES fields(id) ON DELETE CASCADE,
    provider TEXT NOT NULL, external_id TEXT,
    sync_status TEXT NOT NULL DEFAULT 'pending', sync_error TEXT,
    retryable INTEGER NOT NULL DEFAULT 1, last_sync_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    UNIQUE(field_id, provider)
);
CREATE TABLE IF NOT EXISTS satellite_scenes (
    id TEXT PRIMARY KEY, field_id TEXT NOT NULL REFERENCES fields(id),
    provider_scene_id TEXT NOT NULL,
    provider TEXT NOT NULL DEFAULT 'agromonitoring', source_type TEXT,
    acquired_at TIMESTAMP NOT NULL, cloud_percent REAL, coverage_percent REAL,
    statistics TEXT, ndvi_image_path TEXT, truecolor_image_path TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    UNIQUE(field_id, provider_scene_id)
);
CREATE TABLE IF NOT EXISTS field_observations (
    id TEXT PRIMARY KEY, field_id TEXT NOT NULL REFERENCES fields(id),
    source TEXT NOT NULL, metric TEXT NOT NULL, value REAL, unit TEXT,
    payload TEXT, observed_at TIMESTAMP NOT NULL,
    fetched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL, expires_at TIMESTAMP
);
CREATE TABLE IF NOT EXISTS provider_capabilities (
    id TEXT PRIMARY KEY, provider TEXT NOT NULL, capability TEXT NOT NULL,
    field_id TEXT REFERENCES fields(id), status TEXT NOT NULL,
    status_code INTEGER, checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    detail TEXT
);
CREATE TABLE IF NOT EXISTS ai_analysis_runs (
    id TEXT PRIMARY KEY, field_id TEXT NOT NULL REFERENCES fields(id),
    provider TEXT NOT NULL, status TEXT NOT NULL, context_snapshot TEXT,
    context_fingerprint TEXT, model_name TEXT, prompt_version TEXT,
    policy_version TEXT, data_quality TEXT, evidence TEXT, error TEXT,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL, completed_at TIMESTAMP
);
CREATE TABLE IF NOT EXISTS field_recommendations (
    id TEXT PRIMARY KEY, field_id TEXT NOT NULL REFERENCES fields(id),
    analysis_run_id TEXT, category TEXT NOT NULL,
    priority TEXT NOT NULL DEFAULT 'medium', advice TEXT NOT NULL,
    rationale TEXT, confidence REAL, confidence_reason TEXT, evidence TEXT,
    safety_level TEXT NOT NULL DEFAULT 'guarded',
    requires_expert_confirmation INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending', ndvi_at_generation REAL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    feedback_at TIMESTAMP, expires_at TIMESTAMP, outcome TEXT,
    outcome_notes TEXT, outcome_at TIMESTAMP
);
CREATE TABLE IF NOT EXISTS sensors (
    id TEXT PRIMARY KEY, owner_id TEXT REFERENCES users(id),
    field_id TEXT REFERENCES fields(id) ON DELETE SET NULL,
    device_id TEXT NOT NULL UNIQUE, name TEXT,
    sensor_type TEXT NOT NULL DEFAULT 'multi_sensor', battery_level REAL,
    last_seen TIMESTAMP
);
CREATE TABLE IF NOT EXISTS sensor_readings (
    time TIMESTAMP NOT NULL, sensor_id TEXT NOT NULL REFERENCES sensors(id) ON DELETE CASCADE,
    temperature REAL, moisture REAL, humidity REAL, ph REAL, ec REAL,
    npk_n REAL, npk_p REAL, npk_k REAL,
    PRIMARY KEY (time, sensor_id)
);
"""


def _is_sqlite():
    return engine.dialect.name == "sqlite"


@pytest.fixture(scope="module", autouse=True)
def _setup_db():
    if _is_sqlite():
        with engine.connect() as conn:
            for stmt in _CREATE_TABLES.split(";"):
                stmt = stmt.strip()
                if stmt:
                    conn.execute(text(stmt))
            conn.commit()


@pytest.fixture(autouse=True)
def _clean_data():
    yield
    if _is_sqlite():
        with SessionLocal() as db:
            for t in ("sensor_readings", "sensors", "field_recommendations", "ai_analysis_runs",
                       "provider_capabilities", "field_observations", "satellite_scenes",
                       "field_provider_links", "fields", "users"):
                db.execute(text(f"DELETE FROM {t}"))
            db.commit()
    else:
        with SessionLocal() as db:
            for t in ("sensor_readings", "sensors", "field_recommendations", "ai_analysis_runs",
                       "provider_capabilities", "field_observations", "satellite_scenes",
                       "field_provider_links", "fields", "users"):
                db.execute(text(f"DELETE FROM {t} CASCADE"))
            db.commit()


def _make_field_in_db(db, **overrides):
    user = User(firebase_uid=f"sync-{uuid.uuid4()}", email=f"{uuid.uuid4()}@sync.test")
    db.add(user)
    db.flush()

    if _is_sqlite():
        field_id = uuid.UUID(overrides.pop("id", uuid.uuid4().hex))
        poly_id = overrides.pop("agromonitory_poly_id", "test-polygon")
        status = overrides.pop("agro_status", "pending")
        db.execute(
            text("""INSERT INTO fields (id, owner_id, name, crop_type, boundary, area_ha)
                     VALUES (:id, :oid, :name, :crop, :boundary, :area)"""),
            {"id": field_id.hex, "oid": user.id.hex, "name": overrides.pop("name", "Sync Test Field"),
             "crop": overrides.pop("crop_type", "Wheat"),
             "boundary": "POLYGON((0 0, 1 0, 1 1, 0 1, 0 0))",
             "area": 100.0},
        )
        db.execute(
            text("""INSERT INTO field_provider_links (id, field_id, provider, external_id, sync_status)
                     VALUES (:id, :fid, :provider, :ext, :status)"""),
            {"id": uuid.uuid4().hex, "fid": field_id.hex, "provider": "agromonitoring", "ext": poly_id, "status": status}
        )
        db.commit()
        return field_id, user.id

    from geoalchemy2 import WKTElement
    field_id = uuid.UUID(overrides.pop("id", uuid.uuid4().hex) if "id" in overrides else uuid.uuid4().hex)
    poly_id = overrides.pop("agromonitory_poly_id", "test-polygon")
    field = Field(
        id=field_id,
        owner_id=user.id,
        name=overrides.pop("name", "Sync Test Field"),
        crop_type=overrides.pop("crop_type", "Wheat"),
        boundary=WKTElement("POLYGON((0 0, 1 0, 1 1, 0 1, 0 0))", srid=4326),
        area_ha=100.0,
    )
    db.add(field)
    db.flush()
    from app.models.db_models import FieldProviderLink
    link = FieldProviderLink(
        field_id=field.id,
        provider="agromonitoring",
        external_id=poly_id,
        sync_status=overrides.pop("agro_status", "pending")
    )
    db.add(link)
    db.flush()
    return field.id, user.id


def _make_simple_field(**overrides):
    from app.models.db_models import Field
    field_id = uuid.UUID(overrides.pop("id", uuid.uuid4().hex) if "id" in overrides else uuid.uuid4().hex)
    uid = uuid.UUID(overrides.pop("owner_id", uuid.uuid4().hex) if "owner_id" in overrides else uuid.uuid4().hex)
    field = Field(
        id=field_id, owner_id=uid, name="Sync Test Field",
        crop_type="Wheat", area_ha=100.0,
        status="active",
    )
    from app.models.db_models import FieldProviderLink
    field.provider_links = [
        FieldProviderLink(
            field_id=field_id,
            provider="agromonitoring",
            external_id=overrides.get("agromonitory_poly_id", "test-polygon"),
            sync_status=overrides.get("agro_status", "pending"),
            retryable=True,
        )
    ]
    return field


def _row(db, table, field_id):
    return db.execute(
        text(f"SELECT * FROM {table} WHERE field_id = :fid"),
        {"fid": str(field_id)},
    ).fetchone()


def _count(db, table, field_id):
    return db.execute(
        text(f"SELECT COUNT(*) FROM {table} WHERE field_id = :fid"),
        {"fid": str(field_id)},
    ).scalar()


# ---------------------------------------------------------------------------
# Tests — interval_overrides
# ---------------------------------------------------------------------------


def test_override_helper_returns_value():
    from app.services.scheduler import _override
    field = MagicMock()
    field.interval_overrides = {"weather_hours": 3, "ai_hours": 2}
    assert _override(field, "weather_hours") == 3
    assert _override(field, "ai_hours") == 2


def test_override_helper_returns_none_for_unknown_key():
    from app.services.scheduler import _override
    field = MagicMock()
    field.interval_overrides = {"weather_hours": 3}
    assert _override(field, "soil_hours") is None


def test_override_helper_returns_none_when_no_overrides():
    from app.services.scheduler import _override
    field = MagicMock()
    field.interval_overrides = {}
    assert _override(field, "weather_hours") is None


def test_override_helper_returns_none_when_overrides_is_none():
    from app.services.scheduler import _override
    field = MagicMock()
    field.interval_overrides = None
    assert _override(field, "weather_hours") is None


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_sync_satellite_new_scene():
    db = SessionLocal()
    try:
        field_id, _ = _make_field_in_db(db)
        field = _make_simple_field(id=field_id.hex)

        scene_data = {"dt": 1_700_000_000, "type": "s2", "cl": 10, "dc": 90}
        mock_stats = {"ndvi": {"mean": 0.45, "min": 0.1, "max": 0.8}}

        with (
            patch("app.services.scheduler.search_latest_scene", AsyncMock(return_value=scene_data)),
            patch("app.services.scheduler.get_index_statistics", AsyncMock(side_effect=lambda scene, index, fid: mock_stats["ndvi"] if index == "ndvi" else None)),
            patch("app.services.scheduler.cache_scene_image", AsyncMock(side_effect=["/tmp/ndvi.png", "/tmp/tc.png"])),
        ):
            from app.services.scheduler import _sync_satellite
            result = await _sync_satellite(field, db, force=True)
        db.commit()

        assert result == ("available", 200, None)
        scene = _row(db, "satellite_scenes", field_id)
        assert scene is not None
        stats = scene.statistics
        if isinstance(stats, str):
            stats = json.loads(stats)
        assert stats == {"ndvi": mock_stats["ndvi"]}
        assert field.latest_ndvi == 0.45
        link = _row(db, "field_provider_links", field_id)
        assert link.sync_status == "available"
    finally:
        db.close()


@pytest.mark.asyncio
async def test_sync_satellite_duplicate_scene():
    db = SessionLocal()
    try:
        field_id, _ = _make_field_in_db(db)
        field = _make_simple_field(id=field_id.hex)

        scene_data = {"dt": 1_700_000_000, "type": "s2", "cl": 10, "dc": 90}
        provider_scene_id = f"{scene_data['dt']}:{scene_data['type']}:{scene_data['dc']}"
        db.execute(
            text("""INSERT INTO satellite_scenes (id, field_id, provider, provider_scene_id, acquired_at, statistics)
                     VALUES (:id, :fid, :prov, :psid, :dt, '{}')"""),
            {"id": str(uuid.uuid4()), "fid": field_id.hex, "prov": "agromonitoring",
             "psid": provider_scene_id, "dt": datetime.now(timezone.utc)},
        )
        db.commit()

        with (
            patch("app.services.scheduler.search_latest_scene", AsyncMock(return_value=scene_data)),
            patch("app.services.scheduler.get_index_statistics", AsyncMock(side_effect=lambda scene, index, fid: {"mean": 0.45} if index == "ndvi" else None)),
            patch("app.services.scheduler.cache_scene_image", AsyncMock(side_effect=["/tmp/ndvi.png", "/tmp/tc.png"])),
        ):
            from app.services.scheduler import _sync_satellite
            result = await _sync_satellite(field, db, force=True)
        db.commit()

        assert result == ("available", 200, None)
        assert _count(db, "satellite_scenes", field_id) == 1
        link = _row(db, "field_provider_links", field_id)
        assert link.sync_status == "available"
    finally:
        db.close()


@pytest.mark.asyncio
async def test_sync_satellite_no_scene():
    db = SessionLocal()
    try:
        field_id, _ = _make_field_in_db(db)
        field = _make_simple_field(id=field_id.hex)

        with patch("app.services.scheduler.search_latest_scene", AsyncMock(return_value=None)):
            from app.services.scheduler import _sync_satellite
            result = await _sync_satellite(field, db, force=True)
        db.commit()

        assert result == ("pending", 200, "No satellite scene is available in the latest 14-day window.")
        assert _count(db, "satellite_scenes", field_id) == 0
        link = _row(db, "field_provider_links", field_id)
        assert link.sync_status == "pending"
        assert "No satellite scene" in link.sync_error
    finally:
        db.close()


@pytest.mark.asyncio
async def test_sync_soil_valid_data():
    db = SessionLocal()
    try:
        field_id, _ = _make_field_in_db(db)
        field = _make_simple_field(id=field_id.hex)

        soil_data = {
            "moisture": 0.35, "t0": 300.15, "t10": 295.15,
            "surface_temp_c": 27.0, "depth_temp_c": 22.0, "observed_at": 1_700_000_000,
        }

        with patch("app.services.scheduler.get_soil_data", AsyncMock(return_value=soil_data)):
            from app.services.scheduler import _sync_soil
            result = await _sync_soil(field, db, force=True)
        db.commit()

        assert result == ("available", 200, None)
        obs = _row(db, "field_observations", field_id)
        assert obs is not None
        assert obs.value == 0.35
        assert obs.unit == "m3/m3"
    finally:
        db.close()


@pytest.mark.asyncio
async def test_sync_weather_valid_data():
    db = SessionLocal()
    try:
        field_id, _ = _make_field_in_db(db)
        field = _make_simple_field(id=field_id.hex)

        weather_data = {
            "current": {"temp_c": 28, "humidity": 60, "description": "sunny"},
            "forecast_days": [],
        }

        with (
            patch("app.services.scheduler._centroid", return_value=(31.5, 74.3)),
            patch("app.services.scheduler.get_weather_forecast", AsyncMock(return_value=weather_data)),
        ):
            from app.services.scheduler import _sync_weather
            result = await _sync_weather(field, db, force=True)
        db.commit()

        assert result == ("available", 200, None)
        obs = _row(db, "field_observations", field_id)
        assert obs is not None
        payload = obs.payload
        if isinstance(payload, str):
            payload = json.loads(payload)
        assert payload["current"]["temp_c"] == 28
    finally:
        db.close()


@pytest.mark.asyncio
async def test_sync_uvi_with_forecast_entitlement_error():
    db = SessionLocal()
    try:
        field_id, _ = _make_field_in_db(db)
        field = _make_simple_field(id=field_id.hex)
        uvi_data = {"uvi": 5.2}

        from app.services.agromonitoring_service import AgroEntitlementError
        with (
            patch("app.services.scheduler.settings.AGRO_FREE_MODE", False),
            patch("app.services.scheduler.get_current_uvi", AsyncMock(return_value=uvi_data)),
            patch("app.services.scheduler.get_forecast_uvi", AsyncMock(side_effect=AgroEntitlementError("Not entitled", 402))),
        ):
            from app.services.scheduler import _sync_uvi
            result = await _sync_uvi(field, db, force=True)
        db.commit()

        assert result == ("available", 200, None)
        obs = _row(db, "field_observations", field_id)
        assert obs is not None
        assert obs.value == 5.2
        cap = db.execute(
            text("SELECT * FROM provider_capabilities WHERE field_id = :fid AND capability = :c"),
            {"fid": field_id.hex, "c": "uvi_forecast"},
        ).fetchone()
        assert cap is not None
        assert cap.status == "unsupported"
    finally:
        db.close()
