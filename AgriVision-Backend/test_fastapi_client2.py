from fastapi.testclient import TestClient
from app.main import app
from app.core.auth import get_current_user
from app.models.db_models import User
from app.database import SessionLocal
import uuid

db = SessionLocal()
user = db.query(User).first()

def override_get_current_user():
    return user

app.dependency_overrides[get_current_user] = override_get_current_user

client = TestClient(app)
field_id = "204928f3-0ba8-4f1e-8e3c-cc7287ae4b32"
resp = client.get(f"/api/fields/{field_id}/sensor-readings?granularity=daily&hours=720")
for row in resp.json():
    print(f"bucket: {row.get('bucket')}, moisture_avg: {row.get('moisture_avg')}, temperature_avg: {row.get('temperature_avg')}")
