import pytest
from fastapi.testclient import TestClient
from uuid import uuid4
from datetime import datetime, timedelta, timezone

from app.main import app
from app.models.db_models import Field, Sensor, SensorReading, FieldObservation, AIAnalysisRun, FieldRecommendation
from app.database import get_db, SessionLocal
from app.core.auth import get_current_user

# Mock the database override for tests
def _database_override():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# We need a mock user
class MockUser:
    def __init__(self):
        self.id = uuid4()
        self.email = "e2e@agrivision.com"
        self.firebase_uid = "mock-firebase-id"

@pytest.fixture
def e2e_client():
    from app.models.db_models import User
    db = SessionLocal()
    existing_user = db.query(User).filter(User.email == "e2e@agrivision.com").first()
    if existing_user:
        from app.models.db_models import Field, Sensor
        db.query(Field).filter(Field.owner_id == existing_user.id).delete(synchronize_session=False)
        db.query(Sensor).filter(Sensor.owner_id == existing_user.id).delete(synchronize_session=False)
        db.delete(existing_user)
        db.commit()
        
    user = User(id=uuid4(), email="e2e@agrivision.com", firebase_uid="mock-firebase-id")
    db.add(user)
    db.commit()
    
    app.dependency_overrides[get_db] = _database_override
    app.dependency_overrides[get_current_user] = lambda: user
    with TestClient(app) as client:
        yield client, user
    app.dependency_overrides.clear()

def test_full_field_lifecycle(e2e_client):
    client, user = e2e_client
    db = SessionLocal()
    try:
        # 1. Create a field with expected_harvest_date = None
        now = datetime.now(timezone.utc)
        plantation_date = now - timedelta(days=120)
        
        field_payload = {
            "name": "E2E Wheat Field",
            "crop_type": "Wheat",
            "area_ha": 5.0,
            "coordinates": [{"latitude": 31.00, "longitude": 73.00}, {"latitude": 31.01, "longitude": 73.00}, {"latitude": 31.01, "longitude": 73.01}, {"latitude": 31.00, "longitude": 73.01}],
            "plantation_date": plantation_date.isoformat(),
            "expected_harvest_date": None
        }
        
        res = client.post("/api/fields", json=field_payload)
        assert res.status_code == 201, f"Failed to create field: {res.text}"
        field_id = res.json()["id"]
        
        # 2. Register a sensor and bind it to the field
        sensor_id = uuid4()
        sensor = Sensor(id=sensor_id, owner_id=user.id, field_id=field_id, device_id=f"e2e-sensor-{uuid4()}", sensor_type="multi_sensor")
        db.add(sensor)
        db.flush()
        
        # 3. Simulate sensor readings and NDVI
        db.add(SensorReading(time=now, sensor_id=sensor_id, temperature=25.0, moisture=15.0))
        db.add(FieldObservation(field_id=field_id, source="satellite", metric="ndvi", value=0.35, observed_at=now))
        db.flush()
        
        # 4. Simulate AI running and issuing "Harvest Timing" (Mocked since we can't call Gemini in unit tests without mocking)
        run = AIAnalysisRun(field_id=field_id, provider="gemini", status="completed", started_at=now)
        db.add(run)
        db.flush()
        db.add(FieldRecommendation(
            field_id=field_id, 
            analysis_run_id=run.id, 
            category="Harvest Timing", 
            priority="high", 
            advice="Harvest your crop."
        ))
        db.commit()
        
        # 5. Dashboard checks - Verify the frontend would see the high priority Harvest Timing alert
        res = client.get(f"/api/fields/{field_id}/dashboard")
        assert res.status_code == 200
        dashboard = res.json()
        recommendations = dashboard.get("recommendations", [])
        harvest_recs = [r for r in recommendations if r["category"] == "Harvest Timing" and r["priority"] == "high"]
        assert len(harvest_recs) >= 1, "Expected at least one high priority Harvest Timing recommendation in the dashboard payload"
        
        # 6. Delete (Harvest) the field
        res = client.delete(f"/api/fields/{field_id}")
        assert res.status_code == 204
        
        # 7. Verification of deletion edge cases
        # Field should be marked deleted
        assert db.query(Field).filter(Field.id == field_id).count() == 0
        
        # Sensor must NOT be deleted, but unbound (field_id = None)
        sensor_check = db.query(Sensor).filter(Sensor.id == sensor_id).first()
        assert sensor_check is not None, "CRITICAL EDGE CASE FAILURE: Sensor was completely deleted!"
        assert sensor_check.field_id is None, "Sensor was not unbound from the field"
        
    finally:
        db.close()
