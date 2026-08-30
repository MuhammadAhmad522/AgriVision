import json
import uuid
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch

import pytest
from sqlalchemy import text
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.ext.compiler import compiles

from app.database import SessionLocal, engine
from app.core.errors import APIError


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
CREATE TABLE IF NOT EXISTS field_observations (
    id TEXT PRIMARY KEY, field_id TEXT NOT NULL REFERENCES fields(id),
    source TEXT NOT NULL, metric TEXT NOT NULL, value REAL, unit TEXT,
    payload TEXT, observed_at TIMESTAMP NOT NULL,
    fetched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL, expires_at TIMESTAMP
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
    rationale TEXT, confidence REAL, confidence_reason TEXT,
    safety_level TEXT NOT NULL DEFAULT 'guarded',
    requires_expert_confirmation INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending', ndvi_at_generation REAL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    feedback_at TIMESTAMP, expires_at TIMESTAMP, outcome TEXT,
    outcome_notes TEXT, outcome_at TIMESTAMP
);
"""


@pytest.fixture(scope="module", autouse=True)
def _setup_db():
    conn = engine.connect()
    for stmt in _CREATE_TABLES.split(";"):
        stmt = stmt.strip()
        if stmt:
            conn.execute(text(stmt))
    conn.commit()
    conn.close()


@pytest.fixture(autouse=True)
def _clean_data():
    yield
    db = SessionLocal()
    try:
        for t in ("field_recommendations", "ai_analysis_runs", "field_season_memories",
                   "ai_chat_threads", "sensor_readings",
                   "sensors", "field_observations", "fields", "users"):
            # field_season_memories/ai_chat_threads are real migrated tables (not part of
            # _CREATE_TABLES above), guard in case a given DB snapshot predates them.
            if not engine.dialect.has_table(db.connection(), t):
                continue
            db.execute(text(f"DELETE FROM {t}"))
        db.commit()
    finally:
        db.close()


def _make_field(field_id, **overrides):
    from app.models.db_models import Field
    return Field(
        id=field_id,
        owner_id=uuid.UUID(overrides.get("owner_id", uuid.uuid4().hex)),
        name="AI Test Field",
        crop_type=overrides.get("crop_type", "Wheat"),
        boundary="POLYGON((0 0, 1 0, 1 1, 0 1, 0 0))",
        area_ha=100.0,
        status="active",
    )


def _seed_field_and_data(db, **overrides):
    from app.models.db_models import Field, User
    user = User(firebase_uid=f"ai-{uuid.uuid4()}", email=f"{uuid.uuid4()}@ai.test")
    db.add(user)
    db.flush()
    field_id = uuid.uuid4()
    field = Field(
        id=field_id,
        owner_id=user.id,
        name="AI Test Field",
        crop_type=overrides.pop("crop_type", "Wheat"),
        boundary="POLYGON((0 0, 1 0, 1 1, 0 1, 0 0))",
        area_ha=100.0,
        status="active",
    )
    db.add(field)
    db.flush()
    db.commit()
    return field.id, user.id


def _add_observation(db, field_id_hex, metric, payload, observed_at=None):
    obs_id = uuid.uuid4().hex
    observed_at = observed_at or datetime.now(timezone.utc)
    db.execute(
        text("""INSERT INTO field_observations (id, field_id, source, metric, payload, observed_at, fetched_at, expires_at)
                 VALUES (:id, :fid, :src, :metric, :pl, :obs, :fetched, :exp)"""),
        {"id": obs_id, "fid": field_id_hex, "src": "agromonitoring", "metric": metric,
         "pl": json.dumps(payload), "obs": observed_at,
         "fetched": datetime.now(timezone.utc),
         "exp": datetime.now(timezone.utc) + timedelta(hours=6)},
    )


def _mock_provider(recommendations=None, season_memory=None, field_health=None):
    recs = recommendations or [
        {"category": "Irrigation", "priority": "high", "advice": "Water now",
         "confidence": 0.85, "rationale": "Soil is dry",
         "safety_level": "guarded", "requires_expert_confirmation": False,
         "evidence": []},
    ]
    memory_result = season_memory or {"narrative": "Wheat planted; irrigation advised early.", "key_event": ""}
    health_result = field_health or {"score": 82.0, "label": "good", "rationale": "Canopy and soil evidence look normal for this growth stage."}
    provider = AsyncMock()
    provider.name = "gemini"
    provider.model_name = "gemini-2.0-flash"
    provider.recommendations = AsyncMock(return_value={"recommendations": recs, "field_health": health_result})
    provider.summarize_season = AsyncMock(return_value=memory_result)
    return provider


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_ai_run_creates_recommendations():
    db = SessionLocal()
    try:
        field_id, _ = _seed_field_and_data(db)
        _add_observation(db, field_id.hex, "soil_current", {"moisture": 0.35})
        _add_observation(db, field_id.hex, "weather_forecast", {"current": {"temp_c": 28}})
        db.commit()

        field = _make_field(field_id)

        provider = _mock_provider()

        with (
            patch("app.services.scheduler._acquire_source_lock", return_value=True),
            patch("app.services.scheduler.get_ai_provider", return_value=provider),
        ):
            from app.services.scheduler import run_ai_for_field
            await run_ai_for_field(field, db)

        db.commit()

        from app.models.db_models import AIAnalysisRun, FieldRecommendation
        run = db.query(AIAnalysisRun).filter(AIAnalysisRun.field_id == field_id).first()
        assert run is not None
        assert run.status == "completed"
        assert run.data_quality == "good"

        recs = db.query(FieldRecommendation).filter(
            FieldRecommendation.field_id == field_id
        ).all()
        assert len(recs) == 1
        assert recs[0].advice == "Water now"
    finally:
        db.close()


@pytest.mark.asyncio
async def test_field_health_persisted_on_success():
    db = SessionLocal()
    try:
        from app.models.db_models import Field

        field_id, _ = _seed_field_and_data(db)
        _add_observation(db, field_id.hex, "soil_current", {"moisture": 0.35})
        db.commit()

        # Use a real session-attached Field (as run_ai_for_field_id does in production), not
        # the detached _make_field() helper — mutating a detached object's attributes never
        # reaches the database, which would make this test pass even if the real code didn't.
        field = db.query(Field).filter(Field.id == field_id).first()
        provider = _mock_provider(field_health={"score": 88.0, "label": "excellent", "rationale": "Strong canopy and adequate moisture."})

        with (
            patch("app.services.scheduler._acquire_source_lock", return_value=True),
            patch("app.services.scheduler.get_ai_provider", return_value=provider),
        ):
            from app.services.scheduler import run_ai_for_field
            await run_ai_for_field(field, db)
        db.commit()

        db.expire_all()
        persisted = db.query(Field).filter(Field.id == field_id).first()
        assert persisted.latest_health_score == 88.0
        assert persisted.latest_health_label == "excellent"
        assert persisted.latest_health_rationale == "Strong canopy and adequate moisture."
        assert persisted.latest_health_updated_at is not None
    finally:
        db.close()


@pytest.mark.asyncio
async def test_field_health_untouched_on_ai_failure():
    db = SessionLocal()
    try:
        from app.models.db_models import Field

        field_id, _ = _seed_field_and_data(db)
        _add_observation(db, field_id.hex, "soil_current", {"moisture": 0.35})
        db.execute(
            text("UPDATE fields SET latest_health_score = :score, latest_health_label = :label, latest_health_rationale = :rationale WHERE id = :id"),
            {"score": 75.0, "label": "good", "rationale": "Previous run.", "id": field_id.hex},
        )
        db.commit()

        field = db.query(Field).filter(Field.id == field_id).first()
        provider = AsyncMock()
        provider.name = "gemini"
        provider.model_name = "gemini-2.0-flash"
        provider.recommendations = AsyncMock(side_effect=APIError(503, "ai_provider_failed", "Down", retryable=True))

        with (
            patch("app.services.scheduler._acquire_source_lock", return_value=True),
            patch("app.services.scheduler.get_ai_provider", return_value=provider),
        ):
            from app.services.scheduler import run_ai_for_field
            await run_ai_for_field(field, db)
        db.commit()

        db.expire_all()
        persisted = db.query(Field).filter(Field.id == field_id).first()
        assert persisted.latest_health_score == 75.0
        assert persisted.latest_health_label == "good"
        assert persisted.latest_health_rationale == "Previous run."
    finally:
        db.close()


@pytest.mark.asyncio
async def test_ai_run_includes_farmer_reported_context():
    db = SessionLocal()
    try:
        field_id, _ = _seed_field_and_data(db)
        _add_observation(db, field_id.hex, "soil_current", {"moisture": 0.35})
        db.execute(
            text("""INSERT INTO ai_chat_threads (id, field_id, channel, rolling_summary)
                     VALUES (:id, :fid, 'farmer', :summary)"""),
            {"id": uuid.uuid4().hex, "fid": field_id.hex, "summary": "Farmer: I see yellow patches on the east side.\nAdvisor: Noted."},
        )
        db.commit()

        field = _make_field(field_id)
        provider = _mock_provider()

        with (
            patch("app.services.scheduler._acquire_source_lock", return_value=True),
            patch("app.services.scheduler.get_ai_provider", return_value=provider),
        ):
            from app.services.scheduler import run_ai_for_field
            await run_ai_for_field(field, db)
        db.commit()

        from app.models.db_models import AIAnalysisRun
        run = db.query(AIAnalysisRun).filter(AIAnalysisRun.field_id == field_id).first()
        assert run is not None
        assert "yellow patches" in run.context_snapshot["farmer_reported_context"]

        call_kwargs = provider.recommendations.call_args
        sent_context = call_kwargs.args[0] if call_kwargs.args else call_kwargs.kwargs["context"]
        assert "yellow patches" in sent_context["farmer_reported_context"]
    finally:
        db.close()


@pytest.mark.asyncio
async def test_ai_run_skips_duplicate_fingerprint():
    db = SessionLocal()
    try:
        field_id, _ = _seed_field_and_data(db)
        _add_observation(db, field_id.hex, "soil_current", {"moisture": 0.35})
        db.commit()

        field = _make_field(field_id)

        provider = _mock_provider()

        with (
            patch("app.services.scheduler._acquire_source_lock", return_value=True),
            patch("app.services.scheduler.get_ai_provider", return_value=provider),
        ):
            from app.services.scheduler import run_ai_for_field
            await run_ai_for_field(field, db)
        db.commit()

        from app.models.db_models import AIAnalysisRun, FieldRecommendation
        first_count = db.query(AIAnalysisRun).filter(
            AIAnalysisRun.field_id == field_id
        ).count()
        assert first_count == 1

        provider2 = _mock_provider()
        with (
            patch("app.services.scheduler._acquire_source_lock", return_value=True),
            patch("app.services.scheduler.get_ai_provider", return_value=provider2),
        ):
            await run_ai_for_field(field, db)
        db.commit()

        run_count = db.query(AIAnalysisRun).filter(
            AIAnalysisRun.field_id == field_id
        ).count()
        assert run_count == 1

        rec_count = db.query(FieldRecommendation).filter(
            FieldRecommendation.field_id == field_id
        ).count()
        assert rec_count == 1
    finally:
        db.close()


@pytest.mark.asyncio
async def test_ai_run_marks_stale_runs_failed():
    db = SessionLocal()
    try:
        field_id, _ = _seed_field_and_data(db)
        _add_observation(db, field_id.hex, "soil_current", {"moisture": 0.35})
        db.commit()

        stale_run_id = uuid.uuid4().hex
        old_time = datetime.now(timezone.utc) - timedelta(minutes=5)
        db.execute(
            text("""INSERT INTO ai_analysis_runs (id, field_id, provider, status, started_at)
                     VALUES (:id, :fid, :prov, :status, :started)"""),
            {"id": stale_run_id, "fid": field_id.hex, "prov": "gemini",
             "status": "running", "started": old_time},
        )
        db.commit()

        field = _make_field(field_id)
        provider = _mock_provider()

        with (
            patch("app.services.scheduler._acquire_source_lock", return_value=True),
            patch("app.services.scheduler.get_ai_provider", return_value=provider),
        ):
            from app.services.scheduler import run_ai_for_field
            await run_ai_for_field(field, db)
        db.commit()

        from app.models.db_models import AIAnalysisRun
        stale = db.query(AIAnalysisRun).filter(AIAnalysisRun.id == uuid.UUID(stale_run_id)).first()
        assert stale.status == "failed"
        assert stale.error == "AI analysis exceeded its execution window."

        completed_runs = db.query(AIAnalysisRun).filter(
            AIAnalysisRun.field_id == field_id,
            AIAnalysisRun.status == "completed",
        ).count()
        assert completed_runs == 1
    finally:
        db.close()


@pytest.mark.asyncio
async def test_ai_run_handles_provider_failure():
    db = SessionLocal()
    try:
        field_id, _ = _seed_field_and_data(db)
        _add_observation(db, field_id.hex, "soil_current", {"moisture": 0.35})
        db.commit()

        field = _make_field(field_id)

        provider = AsyncMock()
        provider.name = "gemini"
        provider.model_name = "gemini-2.0-flash"
        provider.recommendations = AsyncMock(side_effect=APIError(503, "ai_provider_failed", "Down", retryable=True))

        with (
            patch("app.services.scheduler._acquire_source_lock", return_value=True),
            patch("app.services.scheduler.get_ai_provider", return_value=provider),
        ):
            from app.services.scheduler import run_ai_for_field
            await run_ai_for_field(field, db)
        db.commit()

        from app.models.db_models import AIAnalysisRun
        run = db.query(AIAnalysisRun).filter(
            AIAnalysisRun.field_id == field_id
        ).first()
        assert run is not None
        assert run.status == "failed"
        assert "Down" in run.error
    finally:
        db.close()


@pytest.mark.asyncio
async def test_ai_run_skips_when_within_ai_hours_override():
    db = SessionLocal()
    try:
        field_id, _ = _seed_field_and_data(db)
        _add_observation(db, field_id.hex, "soil_current", {"moisture": 0.35})
        recent_run_id = uuid.uuid4().hex
        db.execute(
            text("""INSERT INTO ai_analysis_runs (id, field_id, provider, status, started_at, completed_at)
                     VALUES (:id, :fid, :prov, :status, :started, :completed)"""),
            {"id": recent_run_id, "fid": field_id.hex, "prov": "gemini", "status": "completed",
             "started": datetime.now(timezone.utc) - timedelta(hours=1),
             "completed": datetime.now(timezone.utc) - timedelta(hours=1)},
        )
        db.commit()

        field = _make_field(field_id)
        field.interval_overrides = {"ai_hours": 24}

        provider = _mock_provider()

        with (
            patch("app.services.scheduler._acquire_source_lock", return_value=True),
            patch("app.services.scheduler.get_ai_provider", return_value=provider),
        ):
            from app.services.scheduler import run_ai_for_field
            await run_ai_for_field(field, db)
        db.commit()

        provider.recommendations.assert_not_called()

        from app.models.db_models import AIAnalysisRun
        run_count = db.query(AIAnalysisRun).filter(AIAnalysisRun.field_id == field_id).count()
        assert run_count == 1  # only the seeded recent run, nothing new
    finally:
        db.close()


@pytest.mark.asyncio
async def test_ai_run_force_bypasses_ai_hours_override():
    db = SessionLocal()
    try:
        field_id, _ = _seed_field_and_data(db)
        _add_observation(db, field_id.hex, "soil_current", {"moisture": 0.35})
        recent_run_id = uuid.uuid4().hex
        db.execute(
            text("""INSERT INTO ai_analysis_runs (id, field_id, provider, status, started_at, completed_at)
                     VALUES (:id, :fid, :prov, :status, :started, :completed)"""),
            {"id": recent_run_id, "fid": field_id.hex, "prov": "gemini", "status": "completed",
             "started": datetime.now(timezone.utc) - timedelta(hours=1),
             "completed": datetime.now(timezone.utc) - timedelta(hours=1)},
        )
        db.commit()

        field = _make_field(field_id)
        field.interval_overrides = {"ai_hours": 24}

        provider = _mock_provider()

        with (
            patch("app.services.scheduler._acquire_source_lock", return_value=True),
            patch("app.services.scheduler.get_ai_provider", return_value=provider),
        ):
            from app.services.scheduler import run_ai_for_field
            await run_ai_for_field(field, db, force=True)
        db.commit()

        provider.recommendations.assert_called_once()

        from app.models.db_models import AIAnalysisRun
        run_count = db.query(AIAnalysisRun).filter(AIAnalysisRun.field_id == field_id).count()
        assert run_count == 2
    finally:
        db.close()


@pytest.mark.asyncio
async def test_season_memory_created_and_narrative_persisted():
    db = SessionLocal()
    try:
        field_id, _ = _seed_field_and_data(db)
        _add_observation(db, field_id.hex, "soil_current", {"moisture": 0.35})
        db.commit()

        field = _make_field(field_id)
        field.plantation_date = datetime(2026, 6, 1, tzinfo=timezone.utc)

        provider = _mock_provider(season_memory={"narrative": "Wheat planted June 1; early tillering underway.", "key_event": ""})

        with (
            patch("app.services.scheduler._acquire_source_lock", return_value=True),
            patch("app.services.scheduler.get_ai_provider", return_value=provider),
        ):
            from app.services.scheduler import run_ai_for_field
            await run_ai_for_field(field, db)
        db.commit()

        from app.models.db_models import FieldSeasonMemory
        db.expire_all()
        memory = db.query(FieldSeasonMemory).filter(FieldSeasonMemory.field_id == field_id).first()
        assert memory is not None
        assert memory.season_ended_at is None
        assert "tillering" in memory.narrative
        assert memory.key_events == []
    finally:
        db.close()


@pytest.mark.asyncio
async def test_season_memory_rotates_on_replant():
    db = SessionLocal()
    try:
        field_id, _ = _seed_field_and_data(db)
        _add_observation(db, field_id.hex, "soil_current", {"moisture": 0.35})
        db.commit()

        field = _make_field(field_id)
        field.plantation_date = datetime(2026, 6, 1, tzinfo=timezone.utc)

        provider = _mock_provider()
        with (
            patch("app.services.scheduler._acquire_source_lock", return_value=True),
            patch("app.services.scheduler.get_ai_provider", return_value=provider),
        ):
            from app.services.scheduler import run_ai_for_field
            await run_ai_for_field(field, db)
        db.commit()

        # Second run, no data change: same season, must return the same active memory (steady state).
        provider2 = _mock_provider()
        with (
            patch("app.services.scheduler._acquire_source_lock", return_value=True),
            patch("app.services.scheduler.get_ai_provider", return_value=provider2),
        ):
            await run_ai_for_field(field, db, force=True)
        db.commit()

        from app.models.db_models import FieldSeasonMemory
        db.expire_all()
        memories = db.query(FieldSeasonMemory).filter(FieldSeasonMemory.field_id == field_id).all()
        assert len(memories) == 1
        assert memories[0].season_ended_at is None

        # Replant: new plantation_date must archive the old season and start a fresh one.
        field.plantation_date = datetime(2026, 10, 1, tzinfo=timezone.utc)
        provider3 = _mock_provider()
        with (
            patch("app.services.scheduler._acquire_source_lock", return_value=True),
            patch("app.services.scheduler.get_ai_provider", return_value=provider3),
        ):
            await run_ai_for_field(field, db, force=True)
        db.commit()

        db.expire_all()
        memories = db.query(FieldSeasonMemory).filter(FieldSeasonMemory.field_id == field_id).order_by(FieldSeasonMemory.season_started_at).all()
        assert len(memories) == 2
        assert memories[0].season_ended_at is not None
        assert memories[1].season_ended_at is None
        assert memories[1].season_started_at.date() == field.plantation_date.date()
    finally:
        db.close()


@pytest.mark.asyncio
async def test_season_memory_key_event_persisted_via_reassignment():
    db = SessionLocal()
    try:
        field_id, _ = _seed_field_and_data(db)
        _add_observation(db, field_id.hex, "soil_current", {"moisture": 0.35})
        db.commit()

        field = _make_field(field_id)
        field.plantation_date = datetime(2026, 6, 1, tzinfo=timezone.utc)

        provider = _mock_provider(season_memory={
            "narrative": "Wheat planted; aphid pressure first observed this cycle.",
            "key_event": "First pest risk (aphids) flagged for this field",
        })

        with (
            patch("app.services.scheduler._acquire_source_lock", return_value=True),
            patch("app.services.scheduler.get_ai_provider", return_value=provider),
        ):
            from app.services.scheduler import run_ai_for_field
            await run_ai_for_field(field, db)
        db.commit()

        from app.models.db_models import FieldSeasonMemory
        # Force a real re-read from the database (not the in-memory Python object) so an
        # in-place .append() that SQLAlchemy failed to detect would show up as lost here.
        db.expire_all()
        memory = db.query(FieldSeasonMemory).filter(FieldSeasonMemory.field_id == field_id).first()
        assert len(memory.key_events) == 1
        assert "aphid" in memory.key_events[0]["description"].lower()
    finally:
        db.close()


@pytest.mark.asyncio
async def test_ai_run_insufficient_data_quality():
    db = SessionLocal()
    try:
        field_id, _ = _seed_field_and_data(db, crop_type="Wheat")
        db.commit()

        field = _make_field(field_id, crop_type="Wheat")

        provider = _mock_provider()

        with (
            patch("app.services.scheduler._acquire_source_lock", return_value=True),
            patch("app.services.scheduler.get_ai_provider", return_value=provider),
        ):
            from app.services.scheduler import run_ai_for_field
            await run_ai_for_field(field, db)
        db.commit()

        from app.models.db_models import AIAnalysisRun
        run = db.query(AIAnalysisRun).filter(
            AIAnalysisRun.field_id == field_id
        ).first()
        assert run is not None
        assert run.data_quality == "insufficient"
    finally:
        db.close()
