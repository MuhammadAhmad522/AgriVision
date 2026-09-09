from app.database import SessionLocal
from app.models.db_models import Sensor

db = SessionLocal()
for s in db.query(Sensor).all():
    print(f"Sensor: {s.id}, field_id: {s.field_id}, owner_id: {s.owner_id}")
