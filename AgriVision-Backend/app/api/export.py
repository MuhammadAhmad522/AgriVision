import csv
import io
from datetime import datetime, timedelta, timezone
from typing import Generator
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from sqlalchemy import func as sa_func
from sqlalchemy.orm import Session

from app.api.fields import owned_field
from app.core.auth import get_current_user
from app.database import get_db
from app.models.db_models import (
    AIChatMessage,
    FieldObservation,
    FieldRecommendation,
    SatelliteScene,
    Sensor,
    SensorReading,
    SensorReadingHourly,
    User,
)

router = APIRouter(prefix="/api/fields/{field_id}/export", tags=["Export"])


def _csv_stream(columns: list[str], rows: Generator[list, None, None]) -> StreamingResponse:
    def generate() -> Generator[str, None, None]:
        buffer = io.StringIO()
        writer = csv.writer(buffer)
        writer.writerow(columns)
        yield buffer.getvalue()
        for row in rows:
            buffer.seek(0)
            buffer.truncate(0)
            writer.writerow(row)
            yield buffer.getvalue()

    return StreamingResponse(
        generate(),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=export.csv"},
    )


def _fmt(val) -> str:
    if val is None:
        return ""
    if isinstance(val, datetime):
        return val.isoformat()
    return str(val)


@router.get("/sensor-readings")
def export_sensor_readings(
    field_id: UUID,
    granularity: str = Query("raw", pattern="^(raw|hourly|daily)$"),
    hours: int = Query(24, ge=1, le=720),
    limit: int = Query(1000, ge=1, le=50000),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    owned_field(db, current_user, field_id)
    sensor_ids = [row[0] for row in db.query(Sensor.id).filter(Sensor.field_id == field_id, Sensor.owner_id == current_user.id).all()]
    if not sensor_ids:
        return _csv_stream(["sensor_id", "time", "no_data"], iter([]))

    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)

    if granularity == "raw":
        cols = ["sensor_id", "time", "temperature", "moisture", "humidity", "ph", "ec", "npk_n", "npk_p", "npk_k"]
        rows = (
            db.query(SensorReading)
            .filter(SensorReading.sensor_id.in_(sensor_ids), SensorReading.time >= cutoff)
            .order_by(SensorReading.time.desc())
            .limit(limit)
            .all()
        )

        def _raw_iter():
            for r in rows:
                yield [_fmt(r.sensor_id), _fmt(r.time), _fmt(r.temperature), _fmt(r.moisture), _fmt(r.humidity), _fmt(r.ph), _fmt(r.ec), _fmt(r.npk_n), _fmt(r.npk_p), _fmt(r.npk_k)]

        return _csv_stream(cols, _raw_iter())

    if granularity == "hourly":
        cols = ["sensor_id", "bucket", "reading_count", "temperature_avg", "temperature_min", "temperature_max", "moisture_avg", "moisture_min", "moisture_max", "humidity_avg", "humidity_min", "humidity_max", "ph_avg", "ph_min", "ph_max", "ec_avg", "ec_min", "ec_max", "npk_n_avg", "npk_n_min", "npk_n_max", "npk_p_avg", "npk_p_min", "npk_p_max", "npk_k_avg", "npk_k_min", "npk_k_max"]
        rows = (
            db.query(SensorReadingHourly)
            .filter(SensorReadingHourly.sensor_id.in_(sensor_ids), SensorReadingHourly.bucket >= cutoff)
            .order_by(SensorReadingHourly.bucket.desc())
            .limit(limit)
            .all()
        )

        def _hourly_iter():
            for r in rows:
                yield [_fmt(r.sensor_id), _fmt(r.bucket), _fmt(r.reading_count), _fmt(r.temperature_avg), _fmt(r.temperature_min), _fmt(r.temperature_max), _fmt(r.moisture_avg), _fmt(r.moisture_min), _fmt(r.moisture_max), _fmt(r.humidity_avg), _fmt(r.humidity_min), _fmt(r.humidity_max), _fmt(r.ph_avg), _fmt(r.ph_min), _fmt(r.ph_max), _fmt(r.ec_avg), _fmt(r.ec_min), _fmt(r.ec_max), _fmt(r.npk_n_avg), _fmt(r.npk_n_min), _fmt(r.npk_n_max), _fmt(r.npk_p_avg), _fmt(r.npk_p_min), _fmt(r.npk_p_max), _fmt(r.npk_k_avg), _fmt(r.npk_k_min), _fmt(r.npk_k_max)]

        return _csv_stream(cols, _hourly_iter())

    cols = ["sensor_id", "bucket", "reading_count", "temperature_avg", "temperature_min", "temperature_max", "moisture_avg", "moisture_min", "moisture_max", "humidity_avg", "humidity_min", "humidity_max", "ph_avg", "ph_min", "ph_max", "ec_avg", "ec_min", "ec_max", "npk_n_avg", "npk_n_min", "npk_n_max", "npk_p_avg", "npk_p_min", "npk_p_max", "npk_k_avg", "npk_k_min", "npk_k_max"]
    daily_rows = (
        db.query(
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
        )
        .filter(SensorReadingHourly.sensor_id.in_(sensor_ids), SensorReadingHourly.bucket >= cutoff)
        .group_by(sa_func.date_trunc("day", SensorReadingHourly.bucket), SensorReadingHourly.sensor_id)
        .order_by(sa_func.date_trunc("day", SensorReadingHourly.bucket).desc())
        .limit(limit)
        .all()
    )

    def _daily_iter():
        for r in daily_rows:
            yield [_fmt(r.sensor_id), _fmt(r.bucket), _fmt(r.reading_count), _fmt(r.temperature_avg), _fmt(r.temperature_min), _fmt(r.temperature_max), _fmt(r.moisture_avg), _fmt(r.moisture_min), _fmt(r.moisture_max), _fmt(r.humidity_avg), _fmt(r.humidity_min), _fmt(r.humidity_max), _fmt(r.ph_avg), _fmt(r.ph_min), _fmt(r.ph_max), _fmt(r.ec_avg), _fmt(r.ec_min), _fmt(r.ec_max), _fmt(r.npk_n_avg), _fmt(r.npk_n_min), _fmt(r.npk_n_max), _fmt(r.npk_p_avg), _fmt(r.npk_p_min), _fmt(r.npk_p_max), _fmt(r.npk_k_avg), _fmt(r.npk_k_min), _fmt(r.npk_k_max)]

    return _csv_stream(cols, _daily_iter())


@router.get("/recommendations")
def export_recommendations(
    field_id: UUID,
    limit: int = Query(500, ge=1, le=5000),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    owned_field(db, current_user, field_id)
    rows = (
        db.query(FieldRecommendation)
        .filter(FieldRecommendation.field_id == field_id)
        .order_by(FieldRecommendation.created_at.desc())
        .limit(limit)
        .all()
    )

    cols = ["id", "category", "priority", "advice", "rationale", "confidence", "confidence_reason", "safety_level", "requires_expert_confirmation", "status", "ndvi_at_generation", "created_at", "expires_at", "outcome", "outcome_notes", "outcome_at", "feedback_at"]

    def _iter():
        for r in rows:
            yield [_fmt(r.id), r.category, r.priority, r.advice, _fmt(r.rationale), _fmt(r.confidence), _fmt(r.confidence_reason), r.safety_level, _fmt(r.requires_expert_confirmation), r.status, _fmt(r.ndvi_at_generation), _fmt(r.created_at), _fmt(r.expires_at), _fmt(r.outcome), _fmt(r.outcome_notes), _fmt(r.outcome_at), _fmt(r.feedback_at)]

    return _csv_stream(cols, _iter())


@router.get("/observations")
def export_observations(
    field_id: UUID,
    limit: int = Query(500, ge=1, le=5000),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    owned_field(db, current_user, field_id)
    rows = (
        db.query(FieldObservation)
        .filter(FieldObservation.field_id == field_id)
        .order_by(FieldObservation.observed_at.desc())
        .limit(limit)
        .all()
    )

    cols = ["id", "source", "metric", "value", "unit", "observed_at", "fetched_at", "expires_at"]

    def _iter():
        for r in rows:
            yield [_fmt(r.id), r.source, r.metric, _fmt(r.value), _fmt(r.unit), _fmt(r.observed_at), _fmt(r.fetched_at), _fmt(r.expires_at)]

    return _csv_stream(cols, _iter())


@router.get("/satellite-scenes")
def export_satellite_scenes(
    field_id: UUID,
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    owned_field(db, current_user, field_id)
    rows = (
        db.query(SatelliteScene)
        .filter(SatelliteScene.field_id == field_id)
        .order_by(SatelliteScene.acquired_at.desc())
        .limit(limit)
        .all()
    )

    cols = ["id", "provider_scene_id", "provider", "source_type", "acquired_at", "cloud_percent", "coverage_percent", "created_at"]

    def _iter():
        for r in rows:
            yield [_fmt(r.id), r.provider_scene_id, r.provider, _fmt(r.source_type), _fmt(r.acquired_at), _fmt(r.cloud_percent), _fmt(r.coverage_percent), _fmt(r.created_at)]

    return _csv_stream(cols, _iter())


@router.get("/chat")
def export_chat(
    field_id: UUID,
    limit: int = Query(500, ge=1, le=5000),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    owned_field(db, current_user, field_id)
    rows = (
        db.query(AIChatMessage)
        .filter(AIChatMessage.field_id == field_id)
        .order_by(AIChatMessage.created_at.desc())
        .limit(limit)
        .all()
    )

    cols = ["id", "role", "content", "status", "created_at"]

    def _iter():
        for r in rows:
            yield [_fmt(r.id), r.role, r.content, r.status, _fmt(r.created_at)]

    return _csv_stream(cols, _iter())
