from app.database import SessionLocal
from app.models.db_models import Field

db = SessionLocal()
f = db.query(Field).filter(Field.id == "204928f3-0ba8-4f1e-8e3c-cc7287ae4b32").first()
print(f"Field: {f.id}, owner_id: {f.owner_id}")
