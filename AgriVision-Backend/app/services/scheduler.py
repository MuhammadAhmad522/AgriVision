import asyncio
import hashlib
import json
import logging
import shutil
from datetime import datetime, timedelta, timezone
from uuid import UUID

from geoalchemy2.functions import ST_AsGeoJSON, ST_Centroid, ST_X, ST_Y
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.errors import APIError
from app.database import SessionLocal
from app.models.db_models import (
    AIAnalysisRun,
    Field,
    FieldDeletionJob,
    FieldObservation,
    FieldRecommendation,
    ProviderCapability,
    SatelliteScene,
    Sensor,
    SensorReading,
    SensorReadingHourly,
)
from app.services.agromonitoring_service import (
    AgroAPIError,
    AgroEntitlementError,
    cache_scene_image,
    create_polygon,
    delete_polygon,
    get_accumulated_precipitation,
    get_accumulated_temperature,
    get_current_uvi,
    get_forecast_uvi,
    get_index_statistics,
    get_soil_data,
    get_weather_forecast,
    search_latest_scene,
)
from app.services.ai_advisor_service import get_ai_provider
from app.services.chat_media_service import get_chat_media_storage

logger = logging.getLogger(__name__)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _is_due(db: Session, field_id: UUID, metric: str, hours: int) -> bool:
    latest = (
        db.query(FieldObservation)
        .filter(FieldObservation.field_id == field_id, FieldObservation.metric == metric)
        .order_by(FieldObservation.fetched_at.desc())
        .first()
    )
    return latest is None or latest.fetched_at <= _utcnow() - timedelta(hours=hours)


def _add_observation(db: Session, field_id: UUID, source: str, metric: str, payload: dict, expires_hours: int, value: float | None = None, unit: str | None = None, observed_at: datetime | None = None) -> None:
    timestamp = observed_at or _utcnow()
    observation = db.query(FieldObservation).filter(
        FieldObservation.field_id == field_id,
        FieldObservation.source == source,
        FieldObservation.metric == metric,
        FieldObservation.observed_at == timestamp,
    ).first()
    if observation is None:
        observation = FieldObservation(
            field_id=field_id,
            source=source,
            metric=metric,
            observed_at=timestamp,
        )
        db.add(observation)
    observation.value = value
    observation.unit = unit
    observation.payload = payload
    observation.fetched_at = _utcnow()
    observation.expires_at = _utcnow() + timedelta(hours=expires_hours)


def _centroid(db: Session, field_id: UUID) -> tuple[float, float]:
    lon = db.query(ST_X(ST_Centroid(Field.boundary))).filter(Field.id == field_id).scalar()
    lat = db.query(ST_Y(ST_Centroid(Field.boundary))).filter(Field.id == field_id).scalar()
    return float(lat), float(lon)


def _capability(db: Session, field_id: UUID, name: str) -> ProviderCapability | None:
    return db.query(ProviderCapability).filter(ProviderCapability.provider == "agromonitoring", ProviderCapability.field_id == field_id, ProviderCapability.capability == name).first()


def _set_capability(db: Session, field_id: UUID, name: str, status_value: str, status_code: int | None = None, detail: str | None = None) -> None:
    capability = _capability(db, field_id, name)
    if capability is None:
        capability = ProviderCapability(provider="agromonitoring", field_id=field_id, capability=name, status=status_value)
        db.add(capability)
    capability.status = status_value
    capability.status_code = status_code
    capability.detail = detail
    capability.checked_at = _utcnow()


def _override(field: Field, key: str) -> int | None:
    overrides = field.interval_overrides
    if overrides and isinstance(overrides, dict):
        return overrides.get(key)
    return None


def _store_derived_accumulations(db: Session, field_id: UUID) -> None:
    if not _is_due(db, field_id, "accumulated_estimates_derived", 24):
        return
    snapshots = (
        db.query(FieldObservation)
        .filter(
            FieldObservation.field_id == field_id,
            FieldObservation.metric == "weather_forecast",
            FieldObservation.observed_at >= _utcnow() - timedelta(days=7),
        )
        .order_by(FieldObservation.observed_at.asc())
        .all()
    )
    degree_days = 0.0
    for current, following in zip(snapshots, snapshots[1:]):
        temperature = ((current.payload or {}).get("current") or {}).get("temp_c")
        if temperature is None:
            continue
        hours = min(max((following.observed_at - current.observed_at).total_seconds() / 3600, 0), 6)
        degree_days += max(float(temperature) - 10.0, 0.0) * hours / 24.0

    rain_by_date: dict[str, float] = {}
    for snapshot in snapshots:
        for day in (snapshot.payload or {}).get("forecast_days", []):
            if day.get("date") and day.get("rain_mm") is not None:
                rain_by_date[str(day["date"])] = float(day["rain_mm"])
    payload = {
        "derived": True,
        "label": "Estimate derived from locally stored weather snapshots; not provider historical data.",
        "window_days": 7,
        "growing_degree_days_base_10c": round(degree_days, 2),
        "forecast_precipitation_estimate_mm": round(sum(rain_by_date.values()), 2),
    }
    _add_observation(db, field_id, "local_derived", "accumulated_estimates_derived", payload, 24)


async def _register_polygon(field: Field, db: Session) -> None:
    if field.agromonitory_poly_id or field.agro_status == "unsupported":
        return
    raw = db.query(ST_AsGeoJSON(Field.boundary)).filter(Field.id == field.id).scalar()
    if not raw:
        field.agro_status = "unavailable"
        field.agro_error = "Stored field boundary is unavailable."
        field.agro_retryable = False
        return
    try:
        polygon_id = await create_polygon(field.name, {"type": "Feature", "properties": {}, "geometry": json.loads(raw)}, field.id)
        field.agromonitory_poly_id = polygon_id
        field.agro_status = "pending"
        field.agro_error = None
        field.agro_retryable = True
    except AgroAPIError as exc:
        field.agro_status = "unavailable"
        field.agro_error = str(exc)
        field.agro_retryable = exc.retryable


def _sync_state_name(metric: str) -> str:
    return f"sync:{metric}"


def _source_is_due(db: Session, field_id: UUID, metric: str, hours: int) -> bool:
    observation = (
        db.query(FieldObservation)
        .filter(FieldObservation.field_id == field_id, FieldObservation.metric == metric)
        .order_by(FieldObservation.fetched_at.desc())
        .first()
    )
    state = _capability(db, field_id, _sync_state_name(metric))
    last_attempt = max(
        (timestamp for timestamp in (observation.fetched_at if observation else None, state.checked_at if state else None) if timestamp),
        default=None,
    )
    return last_attempt is None or last_attempt <= _utcnow() - timedelta(hours=hours)


def _acquire_source_lock(db: Session, field_id: UUID, source: str) -> bool:
    key = f"agro-sync:{field_id}:{source}"
    return bool(db.execute(text("SELECT pg_try_advisory_xact_lock(hashtext(:key))"), {"key": key}).scalar())


def _set_source_state(
    db: Session,
    field_id: UUID,
    metric: str,
    status_value: str,
    status_code: int | None = None,
    detail: str | None = None,
) -> None:
    _set_capability(
        db,
        field_id,
        _sync_state_name(metric),
        status_value,
        status_code,
        detail[:300] if detail else None,
    )


async def _sync_satellite(field: Field, db: Session, *, force: bool = False) -> tuple[str, int | None, str | None] | None:
    sat_hours = _override(field, "satellite_hours") or settings.AGRO_SATELLITE_INTERVAL_HOURS
    if not force and not _source_is_due(db, field.id, "satellite_search", sat_hours):
        return None
    scene_data = await search_latest_scene(field.agromonitory_poly_id, field.id)
    _add_observation(db, field.id, "agromonitoring", "satellite_search", {"found": scene_data is not None}, sat_hours)
    field.last_satellite_sync = _utcnow()
    if scene_data is None:
        field.agro_status = "pending"
        field.agro_error = "No satellite scene is available in the latest 14-day window."
        field.agro_retryable = True
        return ("pending", 200, field.agro_error)
    provider_scene_id = f"{scene_data.get('dt')}:{scene_data.get('type', 'unknown')}:{scene_data.get('dc', '')}"
    existing = db.query(SatelliteScene).filter(SatelliteScene.field_id == field.id, SatelliteScene.provider_scene_id == provider_scene_id).first()
    if existing:
        field.agro_status = "available"
        field.agro_error = None
        field.agro_retryable = True
        return ("available", 200, None)

    statistics = {}
    for index in ("ndvi", "evi", "evi2"):
        stats = await get_index_statistics(scene_data, index, field.id)
        if stats:
            statistics[index] = stats
            mean = stats.get("mean")
            _add_observation(db, field.id, "agromonitoring", index, stats, sat_hours * 2, value=float(mean) if mean is not None else None, observed_at=datetime.fromtimestamp(scene_data["dt"], timezone.utc))
    ndvi_path, truecolor_path = await asyncio.gather(
        cache_scene_image(scene_data, "ndvi", field.id),
        cache_scene_image(scene_data, "truecolor", field.id),
    )
    acquired_at = datetime.fromtimestamp(scene_data.get("dt", int(_utcnow().timestamp())), timezone.utc)
    scene = SatelliteScene(
        field_id=field.id,
        provider_scene_id=provider_scene_id,
        source_type=scene_data.get("type"),
        acquired_at=acquired_at,
        cloud_percent=scene_data.get("cl"),
        coverage_percent=scene_data.get("dc"),
        statistics=statistics,
        ndvi_image_path=ndvi_path,
        truecolor_image_path=truecolor_path,
    )
    db.add(scene)
    ndvi_mean = (statistics.get("ndvi") or {}).get("mean")
    if ndvi_mean is not None:
        field.latest_ndvi = float(ndvi_mean)
    field.agro_status = "available"
    field.agro_error = None
    field.agro_retryable = True
    return ("available", 200, None)


async def _sync_soil(field: Field, db: Session, *, force: bool = False) -> tuple[str, int | None, str | None] | None:
    soil_hours = _override(field, "soil_hours") or settings.AGRO_SOIL_INTERVAL_HOURS
    if not force and not _source_is_due(db, field.id, "soil_current", soil_hours):
        return None
    soil = await get_soil_data(field.agromonitory_poly_id, field.id)
    observed = datetime.fromtimestamp(soil["observed_at"], timezone.utc) if soil.get("observed_at") else _utcnow()
    _add_observation(db, field.id, "agromonitoring", "soil_current", soil, soil_hours, value=soil.get("moisture"), unit="m3/m3", observed_at=observed)
    return ("available", 200, None)


async def _sync_weather(field: Field, db: Session, *, force: bool = False) -> tuple[str, int | None, str | None] | None:
    weather_hours = _override(field, "weather_hours") or settings.AGRO_WEATHER_INTERVAL_HOURS
    if not force and not _source_is_due(db, field.id, "weather_forecast", weather_hours):
        return None
    lat, lon = _centroid(db, field.id)
    weather = await get_weather_forecast(lat, lon, field.id)
    _add_observation(db, field.id, "agromonitoring", "weather_forecast", weather, weather_hours)
    return ("available", 200, None)


async def _sync_uvi(field: Field, db: Session, *, force: bool = False) -> tuple[str, int | None, str | None] | None:
    uvi_hours = _override(field, "uvi_hours") or settings.AGRO_UVI_INTERVAL_HOURS
    if not force and not _source_is_due(db, field.id, "uvi_current", uvi_hours):
        return None
    uvi = await get_current_uvi(field.agromonitory_poly_id, field.id)
    payload = uvi if isinstance(uvi, dict) else {"values": uvi}
    _add_observation(db, field.id, "agromonitoring", "uvi_current", payload, uvi_hours, value=payload.get("uvi"), unit="index")
    if not settings.AGRO_FREE_MODE:
        try:
            forecast = await get_forecast_uvi(field.agromonitory_poly_id, field.id)
            forecast_payload = forecast if isinstance(forecast, dict) else {"values": forecast}
            _add_observation(db, field.id, "agromonitoring", "uvi_forecast", forecast_payload, uvi_hours)
            _set_capability(db, field.id, "uvi_forecast", "supported", 200)
        except AgroAPIError as exc:
            status_value = "unsupported" if isinstance(exc, AgroEntitlementError) or not exc.retryable else "unavailable"
            _set_capability(db, field.id, "uvi_forecast", status_value, exc.status_code, str(exc))
    return ("available", 200, None)


async def _sync_accumulations(field: Field, db: Session, *, force: bool = False) -> tuple[str, int | None, str | None] | None:
    weather_hours = _override(field, "weather_hours") or settings.AGRO_WEATHER_INTERVAL_HOURS
    if settings.AGRO_FREE_MODE:
        _store_derived_accumulations(db, field.id)
        return ("available", 200, None)
    lat, lon = _centroid(db, field.id)
    end = int(_utcnow().timestamp())
    start = int((_utcnow() - timedelta(days=7)).timestamp())
    for name, call in (
        ("accumulated_temperature", get_accumulated_temperature),
        ("accumulated_precipitation", get_accumulated_precipitation),
    ):
        if _capability(db, field.id, name) is not None:
            continue
        try:
            result = await call(lat, lon, start, end, field.id)
            _set_capability(db, field.id, name, "supported", 200)
            _add_observation(db, field.id, "agromonitoring", name, {"values": result, "derived": False}, 24)
        except AgroEntitlementError as exc:
            _set_capability(db, field.id, name, "unsupported", exc.status_code, str(exc))

    if any(
        (capability := _capability(db, field.id, name)) is not None and capability.status == "unsupported"
        for name in ("accumulated_temperature", "accumulated_precipitation")
    ):
        _store_derived_accumulations(db, field.id)
    return ("available", 200, None)


async def _ensure_polygon(field_id: UUID) -> bool:
    db = SessionLocal()
    try:
        if not _acquire_source_lock(db, field_id, "polygon"):
            return False
        field = db.query(Field).filter(Field.id == field_id, Field.status == "active").first()
        if field is None or field.agro_status == "unsupported":
            return False
        await _register_polygon(field, db)
        db.commit()
        return bool(field.agromonitory_poly_id)
    except asyncio.CancelledError:
        db.rollback()
        raise
    except Exception:
        db.rollback()
        field = db.query(Field).filter(Field.id == field_id).first()
        if field:
            field.agro_status = "unavailable"
            field.agro_error = "AgroMonitoring polygon registration failed."
            field.agro_retryable = True
            db.commit()
        logger.exception("AgroMonitoring polygon registration failed field_id=%s", field_id)
        return False
    finally:
        db.close()


async def _run_source(field_id: UUID, metric: str, handler, *, force: bool = False, satellite: bool = False) -> None:
    db = SessionLocal()
    try:
        if not _acquire_source_lock(db, field_id, metric):
            return
        field = db.query(Field).filter(Field.id == field_id, Field.status == "active").first()
        if field is None or not field.agromonitory_poly_id:
            return
        result = await handler(field, db, force=force)
        if result is None:
            db.rollback()
            return
        status_value, status_code, detail = result
        if not satellite:
            _set_source_state(db, field_id, metric, status_value, status_code, detail)
        db.commit()
    except asyncio.CancelledError:
        db.rollback()
        raise
    except AgroEntitlementError as exc:
        db.rollback()
        field = db.query(Field).filter(Field.id == field_id).first()
        if field:
            if satellite:
                field.agro_status = "unsupported"
                field.agro_error = str(exc)
                field.agro_retryable = False
                field.last_satellite_sync = _utcnow()
            else:
                _set_source_state(db, field_id, metric, "unsupported", exc.status_code, str(exc))
            db.commit()
    except AgroAPIError as exc:
        db.rollback()
        field = db.query(Field).filter(Field.id == field_id).first()
        if field:
            if satellite:
                field.agro_status = "unavailable"
                field.agro_error = str(exc)
                field.agro_retryable = exc.retryable
                field.last_satellite_sync = _utcnow()
            else:
                _set_source_state(db, field_id, metric, "unavailable", exc.status_code, str(exc))
            db.commit()
    except Exception:
        db.rollback()
        field = db.query(Field).filter(Field.id == field_id).first()
        if field:
            detail = "AgroMonitoring data refresh failed."
            if satellite:
                field.agro_status = "unavailable"
                field.agro_error = detail
                field.agro_retryable = True
                field.last_satellite_sync = _utcnow()
            else:
                _set_source_state(db, field_id, metric, "unavailable", None, detail)
            db.commit()
        logger.exception("AgroMonitoring source refresh failed field_id=%s source=%s", field_id, metric)
    finally:
        db.close()


async def sync_field_once(field_id: UUID, *, force: bool = False, include_optional: bool = True) -> None:
    if not settings.AGROMONITORING_API_KEY.strip():
        return
    if not await _ensure_polygon(field_id):
        return
    jobs = [
        _run_source(field_id, "satellite_search", _sync_satellite, force=force, satellite=True),
        _run_source(field_id, "soil_current", _sync_soil, force=force),
        _run_source(field_id, "weather_forecast", _sync_weather, force=force),
        _run_source(field_id, "uvi_current", _sync_uvi, force=force),
    ]
    if include_optional:
        jobs.append(_run_source(field_id, "accumulations", _sync_accumulations, force=force))
    await asyncio.gather(*jobs)


async def sync_field_initial(field_id: UUID, timeout_seconds: int | None = None) -> bool:
    timeout = timeout_seconds or settings.AGRO_INITIAL_SYNC_TIMEOUT_SECONDS
    try:
        await asyncio.wait_for(
            sync_field_once(field_id, force=True, include_optional=False),
            timeout=timeout,
        )
        return True
    except TimeoutError:
        logger.info("Initial AgroMonitoring sync timed out field_id=%s timeout=%ss", field_id, timeout)
        return False


async def sync_field_by_id(field_id: UUID, *, force: bool = False) -> None:
    try:
        await sync_field_once(field_id, force=force)
    except asyncio.CancelledError:
        raise
    except Exception:
        logger.exception("Background AgroMonitoring sync failed field_id=%s", field_id)


async def sync_external_data_once() -> None:
    db = SessionLocal()
    try:
        field_ids = [row[0] for row in db.query(Field.id).filter(Field.status == "active").all()]
    finally:
        db.close()
    for field_id in field_ids:
        await sync_field_once(field_id)
        # Re-evaluate immediately after provider data changes. The context
        # fingerprint prevents a paid model call when nothing changed.
        await run_ai_for_field_id(field_id)
    await process_pending_field_deletions()


async def external_data_loop() -> None:
    while True:
        try:
            await sync_external_data_once()
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("External data synchronization cycle failed")
        await asyncio.sleep(settings.AGRO_WORKER_SCAN_SECONDS)


def _generate_telemetry_fallback_recommendations(field: Field, context: dict) -> list[dict]:
    recs = []
    readings = context.get("readings") or []
    crop = (field.crop_type or "Crop").title()

    # 1. Soil Moisture Rule
    moisture_vals = [r.get("moisture") for r in readings if isinstance(r, dict) and r.get("moisture") is not None]
    if moisture_vals:
        avg_m = sum(moisture_vals) / len(moisture_vals)
        if avg_m < 22.0:
            recs.append({
                "category": "Irrigation",
                "priority": "high" if avg_m < 15.0 else "medium",
                "advice": f"Low Soil Moisture detected ({avg_m:.1f}%). Apply 2-3 inches of irrigation to your {crop} field to prevent yield loss.",
                "rationale": f"Current soil moisture reading is below the optimal threshold for {crop} development.",
                "confidence": 0.88,
                "confidence_reason": f"Based on live sensor probe measurements ({avg_m:.1f}%).",
                "evidence": [{"metric": "moisture", "value": round(avg_m, 1)}],
                "safety_level": "routine",
                "requires_expert_confirmation": False,
            })

    # 2. NPK Nitrogen Rule
    npk_n_vals = [r.get("npk_n") for r in readings if isinstance(r, dict) and r.get("npk_n") is not None]
    if npk_n_vals:
        avg_n = sum(npk_n_vals) / len(npk_n_vals)
        if avg_n < 50.0:
            recs.append({
                "category": "Fertilizer Window",
                "priority": "medium",
                "advice": f"Nitrogen Deficiency detected ({avg_n:.1f} mg/kg). Consider top-dressing Nitrogen fertilizer during the current growth stage.\n\n⚠️ Note: Confirm product label, timing, and dose with a qualified local agronomist before application.",
                "rationale": f"Soil Nitrogen level ({avg_n:.1f} mg/kg) is below optimal requirements for {crop}.",
                "confidence": 0.82,
                "confidence_reason": f"Based on live NPK RS485 probe telemetry ({avg_n:.1f} mg/kg).",
                "evidence": [{"metric": "npk_n", "value": round(avg_n, 1)}],
                "safety_level": "guarded",
                "requires_expert_confirmation": True,
            })

    # 3. Satellite NDVI Vegetation Health Rule
    if field.latest_ndvi is not None and field.latest_ndvi < 0.40:
        recs.append({
            "category": "Plant Health",
            "priority": "high" if field.latest_ndvi < 0.25 else "medium",
            "advice": f"Low Vegetation Health Index detected (NDVI: {field.latest_ndvi:.2f}). Inspect the field for signs of pest stress or nutrient deficiency.",
            "rationale": f"Satellite multi-spectral analysis indicates lower-than-normal canopy vigor.",
            "confidence": 0.85,
            "confidence_reason": f"Sentinel-2 Satellite Remote Sensing (NDVI {field.latest_ndvi:.2f}).",
            "evidence": [{"metric": "latest_ndvi", "value": round(field.latest_ndvi, 2)}],
            "safety_level": "routine",
            "requires_expert_confirmation": False,
        })

    # 4. Default Field Monitoring Baseline
    if not recs:
        recs.append({
            "category": "Field Monitoring",
            "priority": "low",
            "advice": f"Continue routine field monitoring for your {crop} field. All telemetry metrics remain within acceptable bounds.",
            "rationale": "Field sensor telemetry and satellite vegetation indices report stable status.",
            "confidence": 0.90,
            "confidence_reason": "Based on multi-source field evidence.",
            "evidence": [],
            "safety_level": "routine",
            "requires_expert_confirmation": False,
        })

    return recs


async def run_ai_for_field(field: Field, db: Session, *, force: bool = False) -> None:
    if not _acquire_source_lock(db, field.id, "ai_analysis"):
        db.rollback()
        return
    stale_before = _utcnow() - timedelta(seconds=max(settings.AI_PROVIDER_TIMEOUT_SECONDS * 2, 120))
    active_run = db.query(AIAnalysisRun).filter(
        AIAnalysisRun.field_id == field.id,
        AIAnalysisRun.status == "running",
        AIAnalysisRun.started_at >= stale_before,
    ).first()
    if active_run:
        db.rollback()
        return
    db.query(AIAnalysisRun).filter(
        AIAnalysisRun.field_id == field.id,
        AIAnalysisRun.status == "running",
        AIAnalysisRun.started_at < stale_before,
    ).update(
        {
            "status": "failed",
            "error": "AI analysis exceeded its execution window.",
            "completed_at": _utcnow(),
        },
        synchronize_session=False,
    )
    observations = db.query(FieldObservation).filter(FieldObservation.field_id == field.id).order_by(FieldObservation.observed_at.desc()).limit(100).all()
    sensors = db.query(Sensor).filter(Sensor.field_id == field.id).all()
    sensor_ids = [sensor.id for sensor in sensors]
    readings = [] if not sensor_ids else (
        db.query(SensorReading)
        .filter(SensorReading.sensor_id.in_(sensor_ids), SensorReading.time >= _utcnow() - timedelta(hours=24))
        .order_by(SensorReading.time.asc())
        .all()
    )
    numeric_readings = {
        name: [float(getattr(item, name)) for item in readings if getattr(item, name) is not None]
        for name in ("temperature", "moisture", "humidity", "ph", "ec", "npk_n", "npk_p", "npk_k")
    }
    sensor_summary = {
        "sensor_count": len(sensors),
        "reading_count": len(readings),
        "optional": len(sensors) == 0,
        "metrics": {
            name: {
                "average": round(sum(values) / len(values), 3),
                "minimum": min(values),
                "maximum": max(values),
                "latest": values[-1],
            }
            for name, values in numeric_readings.items() if values
        },
    }
    fresh_observations = [item for item in observations if item.expires_at is None or item.expires_at >= _utcnow()]
    days_since_planting = max(0, (_utcnow().date() - field.plantation_date.date()).days) if field.plantation_date else None
    context = {
        "field": {
            "name": field.name,
            "area_ha": field.area_ha,
            "crop_type": field.crop_type,
            "plantation_date": field.plantation_date,
            "days_since_planting": days_since_planting,
            "region": "Punjab, Pakistan",
        },
        "latest_ndvi": field.latest_ndvi,
        "observations": [{
            "source": item.source,
            "metric": item.metric,
            "value": item.value,
            "unit": item.unit,
            "payload": item.payload,
            "observed_at": item.observed_at,
            "expires_at": item.expires_at,
            "fresh": item in fresh_observations,
        } for item in observations],
        "readings": [
            {
                "temperature": r.temperature,
                "moisture": r.moisture,
                "humidity": r.humidity,
                "ph": r.ph,
                "ec": r.ec,
                "npk_n": r.npk_n,
                "npk_p": r.npk_p,
                "npk_k": r.npk_k,
            }
            for r in readings
        ],
        "sensor_summary": sensor_summary,
    }
    serializable_context = json.loads(json.dumps(context, default=str))
    data_quality = "good" if field.crop_type and len(fresh_observations) >= 2 else ("limited" if field.crop_type and (fresh_observations or readings) else "insufficient")
    serializable_context["data_quality"] = data_quality
    provider = get_ai_provider()
    fingerprint_payload = json.dumps(serializable_context, sort_keys=True, separators=(",", ":"))
    context_fingerprint = hashlib.sha256(fingerprint_payload.encode("utf-8")).hexdigest()
    duplicate = db.query(AIAnalysisRun).filter(
        AIAnalysisRun.field_id == field.id,
        AIAnalysisRun.status == "completed",
        AIAnalysisRun.context_fingerprint == context_fingerprint,
        AIAnalysisRun.model_name == provider.model_name,
        AIAnalysisRun.prompt_version == settings.AI_PROMPT_VERSION,
        AIAnalysisRun.policy_version == settings.AI_POLICY_VERSION,
    ).first()
    if duplicate and not force:
        db.commit()
        return
    run = AIAnalysisRun(
        field_id=field.id,
        provider=provider.name,
        model_name=provider.model_name,
        prompt_version=settings.AI_PROMPT_VERSION,
        policy_version=settings.AI_POLICY_VERSION,
        context_fingerprint=context_fingerprint,
        data_quality=data_quality,
        evidence=[{"source": item.source, "metric": item.metric, "observed_at": item.observed_at.isoformat(), "fresh": item in fresh_observations} for item in observations[:30]],
        status="running",
        context_snapshot=serializable_context,
    )
    db.add(run)
    db.flush()
    db.commit()
    db.refresh(run)
    try:
        ai_failed = False
        ai_error_msg = None
        try:
            recommendations = await provider.recommendations(serializable_context)
            if not recommendations:
                recommendations = _generate_telemetry_fallback_recommendations(field, serializable_context)
        except APIError as exc:
            ai_failed = True
            ai_error_msg = exc.message
            recommendations = _generate_telemetry_fallback_recommendations(field, serializable_context)
        except Exception as exc:
            ai_failed = True
            ai_error_msg = str(exc)
            recommendations = _generate_telemetry_fallback_recommendations(field, serializable_context)

        for item in recommendations:
            db.query(FieldRecommendation).filter(
                FieldRecommendation.field_id == field.id,
                FieldRecommendation.category == item["category"],
                FieldRecommendation.status == "pending",
            ).update({"status": "superseded"}, synchronize_session=False)
            db.add(FieldRecommendation(
                field_id=field.id,
                analysis_run_id=run.id,
                category=item["category"],
                priority=item["priority"],
                advice=item["advice"],
                rationale=item.get("rationale"),
                confidence=item["confidence"],
                confidence_reason=item.get("confidence_reason"),
                evidence=item.get("evidence", []),
                safety_level=item.get("safety_level", "guarded"),
                requires_expert_confirmation=item.get("requires_expert_confirmation", False),
                ndvi_at_generation=field.latest_ndvi,
                expires_at=_utcnow() + timedelta(days=7),
            ))
        run.status = "failed" if ai_failed else "completed"
        run.error = ai_error_msg if ai_failed else None
        run.completed_at = _utcnow()
        db.commit()
    except asyncio.CancelledError:
        run.status = "failed"
        run.error = "AI analysis was interrupted and will retry."
        run.completed_at = _utcnow()
        db.commit()
        raise
    except Exception:
        logger.exception("Unexpected AI analysis failure field_id=%s", field.id)
        db.rollback()
        run = db.query(AIAnalysisRun).filter(AIAnalysisRun.id == run.id).first()
        if run:
            run.status = "failed"
            run.error = "AI Advisor could not complete the analysis."
            run.completed_at = _utcnow()
            db.commit()


async def run_ai_for_field_id(field_id: UUID, *, force: bool = False) -> None:
    db = SessionLocal()
    try:
        field = db.query(Field).filter(Field.id == field_id, Field.status == "active").first()
        if field:
            await run_ai_for_field(field, db, force=force)
    finally:
        db.close()


async def run_ai_by_field_id(field_id: UUID, *, force: bool = False) -> None:
    await run_ai_for_field_id(field_id, force=force)


async def ai_reasoning_loop() -> None:
    await asyncio.sleep(30)
    while True:
        db = SessionLocal()
        try:
            fields = db.query(Field).filter(Field.status == "active").all()
            for field in fields:
                ai_hours = _override(field, "ai_hours")
                if ai_hours:
                    last_run = db.query(AIAnalysisRun.started_at).filter(
                        AIAnalysisRun.field_id == field.id,
                        AIAnalysisRun.status == "completed",
                    ).order_by(AIAnalysisRun.started_at.desc()).first()
                    if last_run and last_run[0] > _utcnow() - timedelta(hours=ai_hours):
                        continue
                await run_ai_for_field(field, db)
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("AI reasoning cycle failed")
            db.rollback()
        finally:
            db.close()
        await asyncio.sleep(300)


async def process_field_deletion_job(job_id: UUID) -> None:
    db = SessionLocal()
    try:
        job = db.query(FieldDeletionJob).filter(FieldDeletionJob.id == job_id).with_for_update().first()
        if job is None or job.status == "completed":
            return
        job.status = "running"
        job.attempts += 1
        db.commit()
        try:
            if job.provider_polygon_id:
                await delete_polygon(job.provider_polygon_id, job.field_id)
            agro_root = (settings.agro_media_path / str(job.field_id)).resolve()
            allowed_agro_root = settings.agro_media_path.resolve()
            if allowed_agro_root in agro_root.parents and agro_root.exists():
                shutil.rmtree(agro_root)
            get_chat_media_storage().delete_field(job.field_id)
            job = db.query(FieldDeletionJob).filter(FieldDeletionJob.id == job_id).first()
            if job:
                job.status = "completed"
                job.completed_at = _utcnow()
                job.last_error = None
                db.commit()
        except asyncio.CancelledError:
            db.rollback()
            raise
        except Exception as exc:
            db.rollback()
            job = db.query(FieldDeletionJob).filter(FieldDeletionJob.id == job_id).first()
            if job:
                job.status = "pending"
                job.last_error = type(exc).__name__
                backoff_minutes = min(2 ** min(job.attempts, 8), 360)
                job.next_attempt_at = _utcnow() + timedelta(minutes=backoff_minutes)
                db.commit()
            logger.warning("Field deletion cleanup will retry job=%s error=%s", job_id, type(exc).__name__)
    finally:
        db.close()


async def process_pending_field_deletions() -> None:
    db = SessionLocal()
    try:
        job_ids = [row[0] for row in db.query(FieldDeletionJob.id).filter(
            FieldDeletionJob.status == "pending",
            (FieldDeletionJob.next_attempt_at.is_(None)) | (FieldDeletionJob.next_attempt_at <= _utcnow()),
        ).limit(20).all()]
    finally:
        db.close()
    for job_id in job_ids:
        await process_field_deletion_job(job_id)


def _aggregate_sensor_readings() -> None:
    db = SessionLocal()
    try:
        db.execute(text("""
            INSERT INTO sensor_readings_hourly (
                bucket, sensor_id,
                temperature_avg, temperature_min, temperature_max,
                moisture_avg, moisture_min, moisture_max,
                humidity_avg, humidity_min, humidity_max,
                ph_avg, ph_min, ph_max,
                ec_avg, ec_min, ec_max,
                npk_n_avg, npk_n_min, npk_n_max,
                npk_p_avg, npk_p_min, npk_p_max,
                npk_k_avg, npk_k_min, npk_k_max,
                reading_count
            )
            SELECT
                date_trunc('hour', time) AS bucket,
                sensor_id,
                AVG(temperature), MIN(temperature), MAX(temperature),
                AVG(moisture), MIN(moisture), MAX(moisture),
                AVG(humidity), MIN(humidity), MAX(humidity),
                AVG(ph), MIN(ph), MAX(ph),
                AVG(ec), MIN(ec), MAX(ec),
                AVG(npk_n), MIN(npk_n), MAX(npk_n),
                AVG(npk_p), MIN(npk_p), MAX(npk_p),
                AVG(npk_k), MIN(npk_k), MAX(npk_k),
                COUNT(*) AS reading_count
            FROM sensor_readings
            WHERE time >= date_trunc('hour', NOW()) - interval '24 hours'
              AND time < date_trunc('hour', NOW())
            GROUP BY bucket, sensor_id
            ON CONFLICT (sensor_id, bucket) DO NOTHING
        """))
        db.commit()
    except Exception:
        logger.warning("Sensor reading aggregation failed", exc_info=True)
    finally:
        db.close()


def _purge_raw_readings() -> None:
    db = SessionLocal()
    try:
        result = db.execute(
            text("""
                DELETE FROM sensor_readings sr
                USING sensors s, fields f
                WHERE sr.sensor_id = s.id
                  AND s.field_id = f.id
                  AND sr.time < NOW() - COALESCE(
                    (f.interval_overrides->>'retention_days')::int * interval '1 day',
                    interval '14 days'
                  )
            """)
        )
        db.commit()
        if result.rowcount:
            logger.info("Purged %s raw sensor readings", result.rowcount)
    except Exception:
        db.rollback()
        logger.exception("Raw sensor reading purge failed")
    finally:
        db.close()


async def _aggregation_loop() -> None:
    await asyncio.sleep(60)
    while True:
        await asyncio.to_thread(_aggregate_sensor_readings)
        if _utcnow().hour == 3:
            await asyncio.to_thread(_purge_raw_readings)
        await asyncio.sleep(3600)


def start_satellite_sync_worker():
    return asyncio.create_task(external_data_loop())


def start_ai_reasoning_worker():
    return asyncio.create_task(ai_reasoning_loop())
