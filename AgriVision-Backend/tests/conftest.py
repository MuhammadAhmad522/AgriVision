import os
from uuid import uuid4

# Explicitly isolate test executions to the test database, never touching development data
_DEFAULT_TEST_DB = "postgresql://admin:password@localhost:5432/agrivision_test"
os.environ["DATABASE_URL"] = os.getenv("TEST_DATABASE_URL", _DEFAULT_TEST_DB)
os.environ["ENVIRONMENT"] = "testing"

import pytest

from app.database import SessionLocal, engine, Base
from app.models.db_models import User
import app.models.db_models  # noqa: F401


@pytest.fixture(scope="session", autouse=True)
def _ensure_test_database_schema():
    """Ensure all database tables exist on the dedicated test database before tests run."""
    Base.metadata.create_all(bind=engine)


@pytest.fixture(autouse=True)
def _reset_global_state():
    import app.services.agromonitoring_service as agro
    import app.core.rate_limit as rate_limit
    import app.services.ai_advisor_service as ai
    import app.services.chat_media_service as media
    import app.services.mqtt_service as mqtt

    agro._circuit_open_until = 0.0
    agro._failure_count = 0
    agro._inflight.clear()
    rate_limit.rate_limiter._events.clear()
    ai._provider = None
    media._storage = None
    mqtt._device_events.clear()


@pytest.fixture
def test_user():
    db = SessionLocal()
    try:
        user = User(firebase_uid=f"test-{uuid4()}", email=f"{uuid4()}@example.test")
        db.add(user)
        db.commit()
        db.refresh(user)
        db.expunge(user)
        yield user
    finally:
        db.close()
        db2 = SessionLocal()
        try:
            db2.query(User).filter(User.id == user.id).delete(synchronize_session=False)
            db2.commit()
        finally:
            db2.close()


@pytest.fixture
def db_session():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
