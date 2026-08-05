from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func as sa_func
from sqlalchemy.orm import Session

from app.api.fields import owned_field
from app.core.auth import get_current_user
from app.core.errors import APIError
from app.core.rate_limit import rate_limiter
from app.database import get_db
from app.models.db_models import Sensor, SensorReading, SensorReadingHourly, User
from app.schemas.pydantic_schemas import SensorPairRequest, SensorPairResponse, SensorReadingDB, SensorReadingHourlyDB

router = APIRouter(prefix="/api", tags=["Sensors"])


@router.get("/fields/{field_id}/sensor-readings")
def get_field_readings(
    field_id: UUID,
    granularity: str = Query("raw", pattern="^(raw|hourly|daily)$"),
    limit: int = Query(100, ge=1, le=1000),
    hours: int = Query(24, ge=1, le=720),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    owned_field(db, current_user, field_id)
    sensor_ids = [row[0] for row in db.query(Sensor.id).filter(Sensor.field_id == field_id, Sensor.owner_id == current_user.id).all()]
    if not sensor_ids:
        return []

    if granularity == "raw":
        return db.query(SensorReading).filter(
            SensorReading.sensor_id.in_(sensor_ids),
            SensorReading.time >= datetime.now(timezone.utc) - timedelta(hours=hours),
        ).order_by(SensorReading.time.desc()).limit(limit).all()

    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)
    query = db.query(SensorReadingHourly).filter(
        SensorReadingHourly.sensor_id.in_(sensor_ids),
        SensorReadingHourly.bucket >= cutoff,
    ).order_by(SensorReadingHourly.bucket.desc()).limit(limit)

    if granularity == "daily":
        rows = db.query(
            sa_func.date_trunc("day", SensorReadingHourly.bucket).label("bucket"),
            SensorReadingHourly.sensor_id,
            sa_func.avg(SensorReadingHourly.temperature_avg).label("temperature_avg"),
            sa_func.min(SensorReadingHourly.temperature_min).label("temperature_min"),
            sa_func.max(SensorReadingHourly.temperature_max).label("temperature_max"),
            sa_func.avg(SensorReadingHourly.moisture_avg).label("moisture_avg"),
            sa_func.min(SensorReadingHourly.moisture_min).label("moisture_min"),
            sa_func.max(SensorReadingHourly.moisture_max).label("moisture_max"),
            sa_func.avg(SensorReadingHourly.humidity_avg).label("humidity_avg"),
            sa_func.min(SensorReadingHourly.humidity_min).label("humidity_min"),
            sa_func.max(SensorReadingHourly.humidity_max).label("humidity_max"),
            sa_func.avg(SensorReadingHourly.ph_avg).label("ph_avg"),
            sa_func.min(SensorReadingHourly.ph_min).label("ph_min"),
            sa_func.max(SensorReadingHourly.ph_max).label("ph_max"),
            sa_func.avg(SensorReadingHourly.ec_avg).label("ec_avg"),
            sa_func.min(SensorReadingHourly.ec_min).label("ec_min"),
            sa_func.max(SensorReadingHourly.ec_max).label("ec_max"),
            sa_func.avg(SensorReadingHourly.npk_n_avg).label("npk_n_avg"),
            sa_func.min(SensorReadingHourly.npk_n_min).label("npk_n_min"),
            sa_func.max(SensorReadingHourly.npk_n_max).label("npk_n_max"),
            sa_func.avg(SensorReadingHourly.npk_p_avg).label("npk_p_avg"),
            sa_func.min(SensorReadingHourly.npk_p_min).label("npk_p_min"),
            sa_func.max(SensorReadingHourly.npk_p_max).label("npk_p_max"),
            sa_func.avg(SensorReadingHourly.npk_k_avg).label("npk_k_avg"),
            sa_func.min(SensorReadingHourly.npk_k_min).label("npk_k_min"),
            sa_func.max(SensorReadingHourly.npk_k_max).label("npk_k_max"),
            sa_func.sum(SensorReadingHourly.reading_count).label("reading_count"),
        ).filter(
            SensorReadingHourly.sensor_id.in_(sensor_ids),
            SensorReadingHourly.bucket >= cutoff,
        ).group_by(
            sa_func.date_trunc("day", SensorReadingHourly.bucket),
            SensorReadingHourly.sensor_id,
        ).order_by(sa_func.date_trunc("day", SensorReadingHourly.bucket).desc()).limit(limit).all()
        return [dict(r._mapping) for r in rows]

    return query.all()


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
