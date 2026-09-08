from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func as sa_func
from sqlalchemy.orm import Session, joinedload

from app.api.fields import field_readable_by
from app.core.auth import get_current_user
from app.core.config import settings
from app.core.errors import APIError
from app.core.rate_limit import rate_limiter
from app.database import get_db
from app.models.db_models import Sensor, SensorReading, SensorReadingHourly, User
from app.schemas.pydantic_schemas import SensorPairRequest, SensorPairResponse, SensorReadingDB, SensorReadingHourlyDB, SensorResponse

router = APIRouter(prefix="/api", tags=["Sensors"])


def _is_staff(user: User) -> bool:
    return user.role in ("admin", "agronomist")


@router.get("/sensors", response_model=list[SensorResponse])
def get_sensors(
    owner_id: UUID | None = Query(None, description="Staff only: restrict to one farmer's hardware."),
    field_id: UUID | None = Query(None, description="Restrict to probes assigned to one field."),
    unassigned: bool = Query(False, description="Only probes not attached to any field."),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """The hardware fleet.

    This used to filter on `Sensor.owner_id == current_user.id` unconditionally. Sensors
    belong to farmers, and the web portal is staff-only — so every agronomist opening the
    IoT Hardware Fleet page saw an empty table, and any fleet counter derived from it read
    zero. Staff now see the hardware belonging to the farmers whose fields they can read.
    """
    query = db.query(Sensor).options(joinedload(Sensor.owner), joinedload(Sensor.field))

    if _is_staff(current_user):
        if owner_id is not None:
            query = query.filter(Sensor.owner_id == owner_id)
    else:
        query = query.filter(Sensor.owner_id == current_user.id)

    if field_id is not None:
        # Enforces read access on the field, so the filter cannot be used to enumerate
        # hardware on a field the caller may not see.
        field_readable_by(db, current_user, field_id)
        query = query.filter(Sensor.field_id == field_id)

    if unassigned:
        query = query.filter(Sensor.field_id.is_(None))

    return query.order_by(Sensor.name.asc().nulls_last(), Sensor.device_id.asc()).all()


@router.get("/sensors/{device_id}/health")
def get_sensor_health(
    device_id: str,
    hours: int = Query(24, ge=1, le=168),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Reporting behaviour for one probe: is it publishing, how often, and what last.

    "Online" alone cannot distinguish a probe reporting every 30 seconds from one that
    sent a single packet 59 minutes ago and died.
    """
    sensor = db.query(Sensor).options(joinedload(Sensor.field)).filter(Sensor.device_id == device_id).first()
    if sensor is None:
        raise APIError(404, "sensor_not_found", "Sensor not found.")
    if not _is_staff(current_user) and sensor.owner_id != current_user.id:
        raise APIError(403, "forbidden", "You can only inspect your own sensors.")

    since = datetime.now(timezone.utc) - timedelta(hours=hours)
    rows = (
        db.query(SensorReading)
        .filter(SensorReading.sensor_id == sensor.id, SensorReading.time >= since)
        .order_by(SensorReading.time.desc())
        .limit(1000)
        .all()
    )

    latest = rows[0] if rows else None
    # Median gap between consecutive packets describes the real cadence better than a mean,
    # which one long outage would dominate.
    gaps = [
        (rows[i].time - rows[i + 1].time).total_seconds()
        for i in range(len(rows) - 1)
    ]
    gaps = [g for g in gaps if g > 0]
    median_gap = None
    if gaps:
        ordered = sorted(gaps)
        mid = len(ordered) // 2
        median_gap = ordered[mid] if len(ordered) % 2 else (ordered[mid - 1] + ordered[mid]) / 2

    def _metric_coverage(attribute: str) -> int:
        return sum(1 for r in rows if getattr(r, attribute, None) is not None)

    return {
        "device_id": sensor.device_id,
        "sensor_id": str(sensor.id),
        "field_id": str(sensor.field_id) if sensor.field_id else None,
        "field_name": sensor.field_name,
        "window_hours": hours,
        "reading_count": len(rows),
        "median_interval_seconds": median_gap,
        "longest_gap_seconds": max(gaps) if gaps else None,
        "first_reading_at": rows[-1].time if rows else None,
        "last_reading_at": latest.time if latest else None,
        "battery_level": sensor.battery_level,
        "latest": {
            "temperature": latest.temperature if latest else None,
            "moisture": latest.moisture if latest else None,
            "humidity": latest.humidity if latest else None,
            "ph": latest.ph if latest else None,
            "ec": latest.ec if latest else None,
            "npk_n": latest.npk_n if latest else None,
            "npk_p": latest.npk_p if latest else None,
            "npk_k": latest.npk_k if latest else None,
        } if latest else None,
        # Which metrics this probe actually publishes, rather than which columns exist.
        "reporting_metrics": {
            name: _metric_coverage(name)
            for name in ("temperature", "moisture", "humidity", "ph", "ec", "npk_n", "npk_p", "npk_k")
            if _metric_coverage(name) > 0
        },
    }


@router.get("/fields/{field_id}/sensor-readings")
def get_field_readings(
    field_id: UUID,
    granularity: str = Query("raw", pattern="^(raw|hourly|daily)$"),
    limit: int = Query(100, ge=1, le=1000),
    hours: int = Query(24, ge=1, le=720),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Read-only, so staff may read any field's telemetry; sensors belong to the field's
    # owner, not the caller.
    field = field_readable_by(db, current_user, field_id)
    sensor_ids = [row[0] for row in db.query(Sensor.id).filter(Sensor.field_id == field_id, Sensor.owner_id == field.owner_id).all()]
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
    cutoff = datetime.now(timezone.utc) - timedelta(minutes=settings.SENSOR_OFFLINE_CUTOFF_MINUTES)
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

    # Staff install hardware for farmers. Pairing always claimed the device for the caller,
    # so an agronomist provisioning a probe from the web portal claimed it for their own
    # account — and since agronomists own no fields, that probe could never be assigned to
    # anything. An explicit owner_id makes the real workflow expressible.
    target_owner = current_user
    if request.owner_id is not None and request.owner_id != current_user.id:
        if not _is_staff(current_user):
            raise APIError(403, "forbidden", "Only staff can pair hardware on behalf of another account.")
        target_owner = db.query(User).filter(User.id == request.owner_id).first()
        if target_owner is None:
            raise APIError(404, "user_not_found", "That farmer account does not exist.")

    sensor = db.query(Sensor).filter(Sensor.device_id == request.device_id).with_for_update().first()
    if sensor is None:
        raise APIError(404, "sensor_not_found", "Sensor not found. Power it on and start the MQTT bridge, then try again.", retryable=True)
    if sensor.owner_id not in (None, target_owner.id):
        raise APIError(409, "sensor_owned_by_another_tenant", "That sensor is already paired to another account.")

    cutoff = datetime.now(timezone.utc) - timedelta(minutes=settings.SENSOR_OFFLINE_CUTOFF_MINUTES)
    if sensor.last_seen is None or sensor.last_seen < cutoff:
        raise APIError(409, "sensor_not_online", "No recent sensor heartbeat was detected. Check its power and MQTT connection.", retryable=True)

    sensor.owner_id = target_owner.id
    db.commit()
    db.refresh(sensor)
    owner_label = target_owner.email if target_owner.id != current_user.id else "your account"
    return SensorPairResponse(message=f"Sensor paired to {owner_label} and ready to assign to a field.", sensor=sensor)


@router.delete("/sensors/{device_id}", status_code=204)
def unpair_sensor(
    device_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Un-pair a sensor by deleting its record completely.
    
    This cascades and wipes all historical telemetry data for this sensor, ensuring
    no data is leaked to the next owner. The physical sensor will automatically recreate
    an unowned record on its next MQTT heartbeat.
    """
    sensor = db.query(Sensor).filter(Sensor.device_id == device_id).with_for_update().first()
    if sensor is None:
        raise APIError(404, "sensor_not_found", "Sensor not found.")
    
    if sensor.owner_id != current_user.id and not _is_staff(current_user):
        raise APIError(403, "forbidden", "You can only un-pair your own sensors.")
        
    db.delete(sensor)
    db.commit()
    return None
