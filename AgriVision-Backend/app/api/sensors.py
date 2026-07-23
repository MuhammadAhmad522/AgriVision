from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.fields import owned_field
from app.core.auth import get_current_user
from app.core.errors import APIError
from app.core.rate_limit import rate_limiter
from app.database import get_db
from app.models.db_models import Sensor, SensorReading, User
from app.schemas.pydantic_schemas import SensorPairRequest, SensorPairResponse, SensorReadingDB

router = APIRouter(prefix="/api", tags=["Sensors"])


@router.get("/fields/{field_id}/sensor-readings", response_model=list[SensorReadingDB])
def get_field_readings(
    field_id: UUID,
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    owned_field(db, current_user, field_id)
    sensor_ids = [row[0] for row in db.query(Sensor.id).filter(Sensor.field_id == field_id, Sensor.owner_id == current_user.id).all()]
    if not sensor_ids:
        return []
    return (
        db.query(SensorReading)
        .filter(SensorReading.sensor_id.in_(sensor_ids))
        .order_by(SensorReading.time.desc())
        .limit(limit)
        .all()
    )


@router.get("/sensors/verify/{device_id}")
def verify_sensor_connection(device_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    if len(device_id) > 100 or not all(character.isalnum() or character in "._:-" for character in device_id):
        raise APIError(422, "invalid_device_id", "The sensor ID is invalid.")
    sensor = db.query(Sensor).filter(Sensor.device_id == device_id).first()
    if sensor is None:
        return {"is_verified": False, "message": "Hardware ID not found. Ensure the device and serial bridge are running."}
    if sensor.owner_id not in (None, current_user.id):
        raise APIError(409, "sensor_owned_by_another_tenant", "That sensor is already registered to another account.")
    cutoff = datetime.now(timezone.utc) - timedelta(minutes=60)
    if sensor.last_seen and sensor.last_seen >= cutoff:
        return {"is_verified": True, "name": sensor.name, "last_seen": sensor.last_seen, "message": "Hardware verified and active."}
    return {"is_verified": False, "message": "Sensor found but no recent heartbeat was detected."}


@router.post("/sensors/pair", response_model=SensorPairResponse)
async def pair_sensor(
    request: SensorPairRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Claim an online, unowned device for the authenticated tenant.

    A device is paired independently of a field. Field creation/assignment then
    accepts only devices already paired to the same tenant.
    """
    await rate_limiter.check(f"sensor-pair:{current_user.firebase_uid}", 20, 3600)
    sensor = db.query(Sensor).filter(Sensor.device_id == request.device_id).with_for_update().first()
    if sensor is None:
        raise APIError(404, "sensor_not_found", "Sensor not found. Power it on and start the MQTT bridge, then try again.", retryable=True)
    if sensor.owner_id not in (None, current_user.id):
        raise APIError(409, "sensor_owned_by_another_tenant", "That sensor is already paired to another account.")

    cutoff = datetime.now(timezone.utc) - timedelta(minutes=60)
    if sensor.last_seen is None or sensor.last_seen < cutoff:
        raise APIError(409, "sensor_not_online", "No recent sensor heartbeat was detected. Check its power and MQTT connection.", retryable=True)

    sensor.owner_id = current_user.id
    db.commit()
    db.refresh(sensor)
    return SensorPairResponse(message="Sensor paired and ready to assign to a field.", sensor=sensor)
