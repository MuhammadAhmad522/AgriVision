from app.database import SessionLocal
from app.models.db_models import Field
db = SessionLocal()
for f in db.query(Field).all():
    print(f.id, f.name)
