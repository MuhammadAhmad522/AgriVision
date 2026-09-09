from app.database import SessionLocal
from app.api.sensors import get_field_readings
import uuid
db = SessionLocal()
field_id = uuid.UUID('204928f3-0ba8-4f1e-8e3c-cc7287ae4b32')
# We need to mock the current_user.
from app.models.db_models import User
current_user = db.query(User).first()
res = get_field_readings(
    field_id=field_id,
    granularity="hourly",
    limit=1000,
    hours=24,
    db=db,
    current_user=current_user
)
from fastapi.encoders import jsonable_encoder
encoded = jsonable_encoder(res)
print(f"Returned {len(encoded)} records.")
if encoded:
    print(encoded[0])
