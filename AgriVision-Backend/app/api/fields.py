import json
from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, Query, Response, status
from geoalchemy2.functions import ST_AsGeoJSON
from sqlalchemy import func, text
from sqlalchemy.orm import Session

from app.core.auth import get_current_user
from app.core.config import settings
from app.core.errors import APIError
from app.core.rate_limit import rate_limiter
from app.database import get_db
from app.models.db_models import (
    Field,
    FieldDeletionJob,
    FieldObservation,
    FieldRecommendation,
    ProviderCapability,
    SatelliteScene,
    Sensor,
    SensorReading,
    User,
)
from app.schemas.pydantic_schemas import FieldResponse, FieldUpdate, FieldWithSensorsCreate, SensorCreate, SensorResponse

router = APIRouter(prefix="/api/fields", tags=["Fields"])


def _coordinates_to_wkt(coordinates) -> str:
    points = [(point.longitude, point.latitude) for point in coordinates]
    if points[0] != points[-1]:
        points.append(points[0])
    return "POLYGON(({}))".format(", ".join(f"{lon:.8f} {lat:.8f}" for lon, lat in points))


def field_to_response(field: Field, db: Session) -> FieldResponse:
    raw = db.query(ST_AsGeoJSON(Field.boundary)).filter(Field.id == field.id).scalar()
    coordinates: list[dict[str, float]] = []
    if raw:
        exterior = (json.loads(raw).get("coordinates") or [[]])[0]
        if len(exterior) > 1 and exterior[0] == exterior[-1]:
            exterior = exterior[:-1]
        coordinates = [{"longitude": float(point[0]), "latitude": float(point[1])} for point in exterior]

    return FieldResponse(
        id=field.id,
        owner_id=field.owner_id,
        name=field.name,
        coordinates=coordinates,
        area_ha=field.area_ha,
        status=field.status,
        archived_at=field.archived_at,
        created_at=field.created_at,
        updated_at=field.updated_at,
        crop_type=field.crop_type,
        plantation_date=field.plantation_date,
        expected_harvest_date=field.expected_harvest_date,
        agromonitoring_polygon_id=field.agromonitory_poly_id,
        agro_status=field.agro_status,
        agro_error=field.agro_error,
        agro_retryable=field.agro_retryable,
        latest_ndvi=field.latest_ndvi,
        last_satellite_sync=field.last_satellite_sync,
    )


def owned_field(db: Session, user: User, field_id: UUID, *, include_archived: bool = True) -> Field:
    query = db.query(Field).filter(Field.id == field_id, Field.owner_id == user.id)
    if not include_archived:
        query = query.filter(Field.status == "active")
    field = query.first()
    if field is None:
        raise APIError(404, "field_not_found", "Field not found.")
    return field


async def _sync_field_background(field_id: UUID, force: bool = False) -> None:
    from app.services.scheduler import sync_field_once

    await sync_field_once(field_id, force=force)


def _assign_paired_sensor(db: Session, current_user: User, field: Field, sensor_data: SensorCreate) -> Sensor:
    sensor = db.query(Sensor).filter(Sensor.device_id == sensor_data.device_id).with_for_update().first()
    if sensor is None or sensor.owner_id is None:
        raise APIError(409, "sensor_not_paired", "Pair this sensor before assigning it to a field.")
    if sensor.owner_id != current_user.id:
        raise APIError(409, "sensor_owned_by_another_tenant", "That sensor is already paired to another account.")
    if sensor.field_id is not None and sensor.field_id != field.id:
        raise APIError(409, "sensor_already_assigned", "That sensor is already assigned to another field.")
    sensor.field_id = field.id
    sensor.name = sensor_data.name or sensor.name
    sensor.sensor_type = sensor_data.sensor_type
    return sensor


@router.post("", response_model=FieldResponse, status_code=status.HTTP_201_CREATED)
@router.post("/", response_model=FieldResponse, status_code=status.HTTP_201_CREATED, include_in_schema=False)
async def create_field(
    field_data: FieldWithSensorsCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Allow enough headroom for validation retries while still bounding abusive creation traffic.
    await rate_limiter.check(f"field-create:{current_user.firebase_uid}", 20, 3600)
    # Serialize count-and-create for this tenant, including concurrent API requests.
    db.execute(text("SELECT pg_advisory_xact_lock(hashtext(:uid))"), {"uid": current_user.firebase_uid})
    active_count = db.query(func.count(Field.id)).filter(Field.owner_id == current_user.id, Field.status == "active").scalar()
    if active_count >= settings.ACTIVE_FIELD_LIMIT:
        raise APIError(409, "active_field_limit", "You can have at most five fields. Delete one to add another.")

    wkt = _coordinates_to_wkt(field_data.coordinates)
    valid = db.execute(text("SELECT ST_IsValid(ST_GeomFromText(:wkt, 4326))"), {"wkt": wkt}).scalar()
    if not valid:
        raise APIError(422, "invalid_boundary", "The field boundary intersects itself or is otherwise invalid.")
    computed_area = float(db.execute(text("SELECT ST_Area(ST_GeomFromText(:wkt, 4326)::geography) / 10000.0"), {"wkt": wkt}).scalar())
    if computed_area <= 0:
        raise APIError(422, "invalid_boundary", "The field boundary has no measurable area.")

    if computed_area < 1.0 or computed_area > 3000.0:
        raise APIError(
            422,
            "field_area_out_of_range",
            "Field area must be between 1 and 3000 hectares.",
        )

    new_field = Field(
        owner_id=current_user.id,
        name=field_data.name,
        boundary=f"SRID=4326;{wkt}",
        area_ha=computed_area,
        crop_type=field_data.crop_type,
        plantation_date=field_data.plantation_date,
        expected_harvest_date=field_data.expected_harvest_date,
        status="active",
        agro_status="pending" if settings.AGROMONITORING_API_KEY.strip() else "not_configured",
        agro_error=None if settings.AGROMONITORING_API_KEY.strip() else "Satellite data is not connected yet.",
        agro_retryable=bool(settings.AGROMONITORING_API_KEY.strip()),
    )
    db.add(new_field)
    db.flush()

    for sensor_data in field_data.sensors:
        _assign_paired_sensor(db, current_user, new_field, sensor_data)

    db.commit()
    db.refresh(new_field)
    if settings.AGROMONITORING_API_KEY.strip():
        from app.services.scheduler import sync_field_initial

        completed = await sync_field_initial(new_field.id)
        if not completed:
            background_tasks.add_task(_sync_field_background, new_field.id)
        db.expire_all()
        new_field = db.query(Field).filter(Field.id == new_field.id).first()
    return field_to_response(new_field, db)


@router.get("", response_model=list[FieldResponse])
@router.get("/", response_model=list[FieldResponse], include_in_schema=False)
def get_fields(
    include_archived: bool = Query(False),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = db.query(Field).filter(Field.owner_id == current_user.id)
    if not include_archived:
        query = query.filter(Field.status == "active")
    fields = query.order_by(Field.created_at.asc()).all()
    return [field_to_response(field, db) for field in fields]


@router.get("/{field_id}", response_model=FieldResponse)
def get_field(field_id: UUID, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return field_to_response(owned_field(db, current_user, field_id), db)


@router.post("/{field_id}/sensors", response_model=SensorResponse)
def assign_sensor(
    field_id: UUID,
    sensor_data: SensorCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    field = owned_field(db, current_user, field_id, include_archived=False)
    sensor = _assign_paired_sensor(db, current_user, field, sensor_data)
    db.commit()
    db.refresh(sensor)
    return sensor


@router.get("/{field_id}/sensors", response_model=list[SensorResponse])
def get_field_sensors(
    field_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    field = owned_field(db, current_user, field_id)
    return (
        db.query(Sensor)
        .filter(Sensor.field_id == field.id, Sensor.owner_id == current_user.id)
        .order_by(Sensor.name.asc().nulls_last(), Sensor.device_id.asc())
        .all()
    )


@router.patch("/{field_id}", response_model=FieldResponse)
def update_field(field_id: UUID, update: FieldUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    field = owned_field(db, current_user, field_id, include_archived=False)
    for key, value in update.model_dump(exclude_unset=True).items():
        setattr(field, key, value)
    if field.plantation_date and field.expected_harvest_date and field.expected_harvest_date <= field.plantation_date:
        raise APIError(422, "invalid_harvest_date", "Expected harvest date must be after plantation date.")
    db.commit()
    db.refresh(field)
    return field_to_response(field, db)


@router.post("/{field_id}/harvest", deprecated=True)
def harvest_field_removed(
    field_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    owned_field(db, current_user, field_id)
    raise APIError(410, "field_archiving_removed", "Field archiving is no longer supported. Update the app to permanently delete a field.")


@router.delete("/{field_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_field(
    field_id: UUID,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    field = (
        db.query(Field)
        .filter(Field.id == field_id, Field.owner_id == current_user.id)
        .with_for_update()
        .first()
    )
    if field is None:
        raise APIError(404, "field_not_found", "Field not found.")
    polygon_id = field.agromonitory_poly_id
    field.status = "deleting"
    sensor_ids = [row[0] for row in db.query(Sensor.id).filter(Sensor.field_id == field_id, Sensor.owner_id == current_user.id).all()]
    if sensor_ids:
        db.query(Sensor).filter(Sensor.id.in_(sensor_ids)).delete(synchronize_session=False)
    job = FieldDeletionJob(
        field_id=field_id,
        provider_polygon_id=polygon_id,
        media_paths=[f"agro/{field_id}", f"chat/{field_id}"],
        status="pending",
    )
    db.add(job)
    db.flush()
    db.delete(field)
    db.commit()
    from app.services.scheduler import process_field_deletion_job

    background_tasks.add_task(process_field_deletion_job, job.id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


def _latest_observation(db: Session, field_id: UUID, metric: str) -> FieldObservation | None:
    return (
        db.query(FieldObservation)
        .filter(FieldObservation.field_id == field_id, FieldObservation.metric == metric)
        .order_by(FieldObservation.observed_at.desc())
        .first()
    )


def _source_state(db: Session, field_id: UUID, metric: str) -> ProviderCapability | None:
    return db.query(ProviderCapability).filter(
        ProviderCapability.provider == "agromonitoring",
        ProviderCapability.field_id == field_id,
        ProviderCapability.capability == f"sync:{metric}",
    ).first()


def _source_block(
    observation: FieldObservation | None,
    source_state: ProviderCapability | None = None,
    *,
    provider_configured: bool = True,
    label: str = "Data",
) -> dict:
    if observation is None:
        if not provider_configured:
            return {"status": "not_configured", "last_updated": None, "data": None, "message": f"{label} is not connected yet.", "retryable": False}
        if source_state is not None and source_state.status in {"unavailable", "unsupported"}:
            return {
                "status": source_state.status,
                "last_updated": source_state.checked_at,
                "data": None,
                "message": source_state.detail or f"{label} is currently unavailable.",
                "retryable": source_state.status == "unavailable",
            }
        return {"status": "pending", "last_updated": None, "data": None, "message": f"{label} is being prepared.", "retryable": True}
    now = datetime.now(timezone.utc)
    failed_refresh = source_state is not None and source_state.status == "unavailable"
    status_value = "stale" if failed_refresh or (observation.expires_at and observation.expires_at < now) else "available"
    return {
        "status": status_value,
        "last_updated": observation.observed_at,
        "data": observation.payload,
        "message": (source_state.detail if failed_refresh else f"The latest {label.lower()} snapshot is stale.") if status_value == "stale" else None,
        "retryable": status_value == "stale",
    }


@router.post("/{field_id}/data-refresh", status_code=status.HTTP_202_ACCEPTED)
async def refresh_field_data(
    field_id: UUID,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    field = owned_field(db, current_user, field_id, include_archived=False)
    if not settings.AGROMONITORING_API_KEY.strip():
        raise APIError(503, "agromonitoring_not_configured", "Satellite and weather services are not connected yet.")
    if field.agro_status == "unsupported":
        raise APIError(409, "agromonitoring_unsupported", field.agro_error or "This field is not supported by the satellite provider.")
    await rate_limiter.check(f"provider-refresh:{current_user.firebase_uid}:{field_id}", 4, 3600)
    background_tasks.add_task(_sync_field_background, field_id, True)
    return {"status": "accepted", "message": "Field data refresh queued."}


@router.get("/{field_id}/dashboard")
def get_dashboard(field_id: UUID, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    field = owned_field(db, current_user, field_id)
    sensors = db.query(Sensor).filter(Sensor.field_id == field.id, Sensor.owner_id == current_user.id).all()
    sensor_ids = [sensor.id for sensor in sensors]
    latest_readings = []
    if sensor_ids:
        latest_readings = (
            db.query(SensorReading)
            .filter(SensorReading.sensor_id.in_(sensor_ids))
            .order_by(SensorReading.time.desc())
            .limit(50)
            .all()
        )
    recommendations = (
        db.query(FieldRecommendation)
        .filter(FieldRecommendation.field_id == field.id)
        .order_by(FieldRecommendation.created_at.desc())
        .limit(10)
        .all()
    )
    scene = db.query(SatelliteScene).filter(SatelliteScene.field_id == field.id).order_by(SatelliteScene.acquired_at.desc()).first()
    provider_configured = bool(settings.AGROMONITORING_API_KEY.strip())
    if scene is None:
        satellite_status = field.agro_status if provider_configured or field.agro_status == "unsupported" else "not_configured"
    else:
        satellite_status = "stale" if field.agro_status in {"pending", "unavailable"} else "available"
    satellite = {
        "status": satellite_status,
        "last_updated": scene.acquired_at if scene else field.last_satellite_sync,
        "data": None if scene is None else {
            "scene_id": scene.id,
            "acquired_at": scene.acquired_at,
            "cloud_percent": scene.cloud_percent,
            "coverage_percent": scene.coverage_percent,
            "statistics": scene.statistics,
            "ndvi_image_url": f"/api/fields/{field.id}/satellite/latest/ndvi" if scene.ndvi_image_path else None,
            "truecolor_image_url": f"/api/fields/{field.id}/satellite/latest/truecolor" if scene.truecolor_image_path else None,
        },
        "message": field.agro_error if provider_configured or field.agro_status == "unsupported" else "Satellite data is not connected yet.",
        "retryable": bool(field.agro_retryable and provider_configured),
    }
    return {
        "field": field_to_response(field, db).model_dump(),
        "sources": {
            "satellite": satellite,
            "soil": _source_block(_latest_observation(db, field.id, "soil_current"), _source_state(db, field.id, "soil_current"), provider_configured=provider_configured, label="Soil data"),
            "weather": _source_block(_latest_observation(db, field.id, "weather_forecast"), _source_state(db, field.id, "weather_forecast"), provider_configured=provider_configured, label="Weather data"),
            "uvi": _source_block(_latest_observation(db, field.id, "uvi_current"), _source_state(db, field.id, "uvi_current"), provider_configured=provider_configured, label="UV data"),
            "sensors": {
                "status": "not_configured" if not sensors else ("available" if latest_readings else "unavailable"),
                "last_updated": latest_readings[0].time if latest_readings else None,
                "data": latest_readings,
                "configured_count": len(sensors),
                "reporting_count": len({reading.sensor_id for reading in latest_readings}),
                "message": "IoT monitoring is optional for this field." if not sensors else (None if latest_readings else "The paired sensor has not reported any readings yet."),
                "retryable": bool(sensors and not latest_readings),
            },
        },
        "recommendations": recommendations,
    }


@router.get("/{field_id}/weather-soil", include_in_schema=False)
@router.get("/{field_id}/weather-soil/", include_in_schema=False)
def weather_soil_compat(field_id: UUID, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    owned_field(db, current_user, field_id)
    configured = bool(settings.AGROMONITORING_API_KEY.strip())
    soil = _source_block(_latest_observation(db, field_id, "soil_current"), _source_state(db, field_id, "soil_current"), provider_configured=configured, label="Soil data")
    weather = _source_block(_latest_observation(db, field_id, "weather_forecast"), _source_state(db, field_id, "weather_forecast"), provider_configured=configured, label="Weather data")
    return {
        "field_id": field_id,
        "soil": soil["data"] or {"moisture": None, "surface_temp_c": None, "depth_temp_c": None, "source": soil["status"]},
        "weather": weather["data"] or {"current": {"temp_c": None, "humidity": None, "description": None}, "forecast_days": [], "source": weather["status"]},
    }
