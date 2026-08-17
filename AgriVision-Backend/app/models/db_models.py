import uuid

from geoalchemy2 import Geometry
from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    firebase_uid = Column(String(128), unique=True, index=True, nullable=False)
    email = Column(String(320), unique=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    fields = relationship("Field", back_populates="owner")


class Field(Base):
    __tablename__ = "fields"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    owner_id = Column(PG_UUID(as_uuid=True), ForeignKey("users.id"), index=True, nullable=False)
    name = Column(String(100), nullable=False)
    crop_type = Column(String(80))
    plantation_date = Column(DateTime(timezone=True))
    expected_harvest_date = Column(DateTime(timezone=True))
    boundary = Column(Geometry("POLYGON", srid=4326), nullable=False)
    area_ha = Column(Float, nullable=False)

    status = Column(String(20), nullable=False, default="active", index=True)
    archived_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    latest_ndvi = Column(Float)
    interval_overrides = Column(JSONB, nullable=False, server_default=text("'{}'::jsonb"))

    owner = relationship("User", back_populates="fields")
    provider_links = relationship("FieldProviderLink", back_populates="field", passive_deletes=True)
    # Child rows are removed by the database. passive_deletes prevents SQLAlchemy from
    # trying to null non-nullable foreign keys before the ON DELETE CASCADE executes.
    sensors = relationship("Sensor", back_populates="field", passive_deletes=True)
    recommendations = relationship("FieldRecommendation", back_populates="field", order_by="desc(FieldRecommendation.created_at)", passive_deletes=True)
    observations = relationship("FieldObservation", back_populates="field", order_by="desc(FieldObservation.observed_at)", passive_deletes=True)
    satellite_scenes = relationship("SatelliteScene", back_populates="field", order_by="desc(SatelliteScene.acquired_at)", passive_deletes=True)


class FieldProviderLink(Base):
    __tablename__ = "field_provider_links"
    __table_args__ = (UniqueConstraint("field_id", "provider", name="uq_field_provider_link"),)

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    field_id = Column(PG_UUID(as_uuid=True), ForeignKey("fields.id", ondelete="CASCADE"), index=True, nullable=False)
    provider = Column(String(40), nullable=False)
    external_id = Column(String(160), index=True)
    sync_status = Column(String(24), nullable=False, default="pending")
    sync_error = Column(String(500))
    retryable = Column(Boolean, nullable=False, default=True)
    last_sync_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    field = relationship("Field", back_populates="provider_links")


class Sensor(Base):
    __tablename__ = "sensors"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    owner_id = Column(PG_UUID(as_uuid=True), ForeignKey("users.id"), index=True)
    field_id = Column(PG_UUID(as_uuid=True), ForeignKey("fields.id", ondelete="SET NULL"), index=True)
    device_id = Column(String(100), unique=True, index=True, nullable=False)
    name = Column(String(100))
    sensor_type = Column(String(50), default="multi_sensor", nullable=False)
    battery_level = Column(Float)
    last_seen = Column(DateTime(timezone=True))

    field = relationship("Field", back_populates="sensors")


class SensorReading(Base):
    __tablename__ = "sensor_readings"

    time = Column(DateTime(timezone=True), primary_key=True, default=func.now())
    sensor_id = Column(PG_UUID(as_uuid=True), ForeignKey("sensors.id", ondelete="CASCADE"), primary_key=True)
    temperature = Column(Float)
    moisture = Column(Float)
    humidity = Column(Float)
    ph = Column(Float)
    ec = Column(Float)
    npk_n = Column(Float)
    npk_p = Column(Float)
    npk_k = Column(Float)


class FieldObservation(Base):
    __tablename__ = "field_observations"
    __table_args__ = (UniqueConstraint("field_id", "source", "metric", "observed_at", name="uq_field_observation"),)

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    field_id = Column(PG_UUID(as_uuid=True), ForeignKey("fields.id", ondelete="CASCADE"), index=True, nullable=False)
    source = Column(String(40), index=True, nullable=False)
    metric = Column(String(60), index=True, nullable=False)
    value = Column(Float)
    unit = Column(String(30))
    payload = Column(JSONB)
    observed_at = Column(DateTime(timezone=True), index=True, nullable=False)
    fetched_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    expires_at = Column(DateTime(timezone=True), index=True)

    field = relationship("Field", back_populates="observations")


class SatelliteScene(Base):
    __tablename__ = "satellite_scenes"
    __table_args__ = (UniqueConstraint("field_id", "provider_scene_id", name="uq_field_satellite_scene"),)

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    field_id = Column(PG_UUID(as_uuid=True), ForeignKey("fields.id", ondelete="CASCADE"), index=True, nullable=False)
    provider_scene_id = Column(String(160), nullable=False)
    provider = Column(String(40), nullable=False, default="agromonitoring")
    source_type = Column(String(20))
    acquired_at = Column(DateTime(timezone=True), index=True, nullable=False)
    cloud_percent = Column(Float)
    coverage_percent = Column(Float)
    statistics = Column(JSONB)
    ndvi_image_path = Column(String(500))
    truecolor_image_path = Column(String(500))
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    field = relationship("Field", back_populates="satellite_scenes")


class AIAnalysisRun(Base):
    __tablename__ = "ai_analysis_runs"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    field_id = Column(PG_UUID(as_uuid=True), ForeignKey("fields.id", ondelete="CASCADE"), index=True, nullable=False)
    provider = Column(String(40), nullable=False)
    status = Column(String(20), nullable=False)
    context_snapshot = Column(JSONB)
    context_fingerprint = Column(String(64), index=True)
    model_name = Column(String(100))
    prompt_version = Column(String(40))
    policy_version = Column(String(40))
    data_quality = Column(String(20))
    evidence = Column(JSONB)
    error = Column(String(500))
    started_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    completed_at = Column(DateTime(timezone=True))


class FieldRecommendation(Base):
    __tablename__ = "field_recommendations"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    field_id = Column(PG_UUID(as_uuid=True), ForeignKey("fields.id", ondelete="CASCADE"), index=True, nullable=False)
    analysis_run_id = Column(PG_UUID(as_uuid=True), ForeignKey("ai_analysis_runs.id", ondelete="SET NULL"))
    category = Column(String(50), nullable=False)
    priority = Column(String(20), nullable=False, default="medium")
    advice = Column(Text, nullable=False)
    rationale = Column(Text)
    confidence = Column(Float)
    confidence_reason = Column(String(500))
    safety_level = Column(String(20), nullable=False, default="guarded")
    requires_expert_confirmation = Column(Boolean, nullable=False, default=False)
    status = Column(String(20), nullable=False, default="pending")
    ndvi_at_generation = Column(Float)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    feedback_at = Column(DateTime(timezone=True))
    expires_at = Column(DateTime(timezone=True))
    outcome = Column(String(20))
    outcome_notes = Column(Text)
    outcome_at = Column(DateTime(timezone=True))

    field = relationship("Field", back_populates="recommendations")


class AIChatThread(Base):
    __tablename__ = "ai_chat_threads"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    field_id = Column(PG_UUID(as_uuid=True), ForeignKey("fields.id", ondelete="CASCADE"), unique=True, index=True, nullable=False)
    rolling_summary = Column(Text)
    summarized_through = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)


class AIChatMessage(Base):
    __tablename__ = "ai_chat_messages"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    thread_id = Column(PG_UUID(as_uuid=True), ForeignKey("ai_chat_threads.id", ondelete="CASCADE"), index=True, nullable=False)
    reply_to_message_id = Column(PG_UUID(as_uuid=True), ForeignKey("ai_chat_messages.id", ondelete="CASCADE"), index=True)
    role = Column(String(20), nullable=False)
    content = Column(Text, nullable=False)
    idempotency_key = Column(String(100), index=True)
    status = Column(String(20), nullable=False, default="completed")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class ChatAttachment(Base):
    __tablename__ = "chat_attachments"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    message_id = Column(PG_UUID(as_uuid=True), ForeignKey("ai_chat_messages.id", ondelete="CASCADE"), index=True, nullable=False)
    storage_key = Column(String(500), unique=True, nullable=False)
    mime_type = Column(String(50), nullable=False)
    byte_size = Column(Integer, nullable=False)
    width = Column(Integer, nullable=False)
    height = Column(Integer, nullable=False)
    sha256 = Column(String(64), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class ProviderCapability(Base):
    __tablename__ = "provider_capabilities"
    __table_args__ = (UniqueConstraint("provider", "capability", "field_id", name="uq_provider_capability"),)

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    provider = Column(String(40), nullable=False)
    capability = Column(String(80), nullable=False)
    field_id = Column(PG_UUID(as_uuid=True), ForeignKey("fields.id", ondelete="CASCADE"), index=True)
    status = Column(String(20), nullable=False)
    status_code = Column(Integer)
    checked_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    detail = Column(String(300))


class ProviderRequestLog(Base):
    __tablename__ = "provider_request_logs"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    provider = Column(String(40), index=True, nullable=False)
    endpoint = Column(String(100), index=True, nullable=False)
    field_id = Column(PG_UUID(as_uuid=True), ForeignKey("fields.id", ondelete="CASCADE"), index=True)
    outcome = Column(String(20), nullable=False)
    status_code = Column(Integer)
    cache_hit = Column(Boolean, nullable=False, default=False)
    duration_ms = Column(Integer)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class ProviderCache(Base):
    __tablename__ = "provider_cache"

    cache_key = Column(String(64), primary_key=True)
    provider = Column(String(40), index=True, nullable=False)
    endpoint = Column(String(100), index=True, nullable=False)
    field_id = Column(PG_UUID(as_uuid=True), ForeignKey("fields.id", ondelete="CASCADE"), index=True)
    response_payload = Column(JSONB, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    expires_at = Column(DateTime(timezone=True), index=True, nullable=False)


class FieldDeletionJob(Base):
    __tablename__ = "field_deletion_jobs"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    field_id = Column(PG_UUID(as_uuid=True), index=True, nullable=False)
    provider_polygon_id = Column(String(64))
    media_paths = Column(JSONB, nullable=False, default=list)
    status = Column(String(20), nullable=False, default="pending", index=True)
    attempts = Column(Integer, nullable=False, default=0)
    last_error = Column(String(500))
    next_attempt_at = Column(DateTime(timezone=True), index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    completed_at = Column(DateTime(timezone=True))


class SensorReadingHourly(Base):
    __tablename__ = "sensor_readings_hourly"

    bucket = Column(DateTime(timezone=True), primary_key=True)
    sensor_id = Column(PG_UUID(as_uuid=True), ForeignKey("sensors.id", ondelete="CASCADE"), primary_key=True)
    temperature_avg = Column(Float)
    temperature_min = Column(Float)
    temperature_max = Column(Float)
    moisture_avg = Column(Float)
    moisture_min = Column(Float)
    moisture_max = Column(Float)
    humidity_avg = Column(Float)
    humidity_min = Column(Float)
    humidity_max = Column(Float)
    ph_avg = Column(Float)
    ph_min = Column(Float)
    ph_max = Column(Float)
    ec_avg = Column(Float)
    ec_min = Column(Float)
    ec_max = Column(Float)
    npk_n_avg = Column(Float)
    npk_n_min = Column(Float)
    npk_n_max = Column(Float)
    npk_p_avg = Column(Float)
    npk_p_min = Column(Float)
    npk_p_max = Column(Float)
    npk_k_avg = Column(Float)
    npk_k_min = Column(Float)
    npk_k_max = Column(Float)
    reading_count = Column(Integer, nullable=False)


class AgronomyKnowledgeDocument(Base):
    __tablename__ = "agronomy_knowledge_documents"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    external_id = Column(String(160), unique=True, nullable=False)
    title = Column(String(300), nullable=False)
    source_url = Column(String(1000), nullable=False)
    crop = Column(String(80), index=True, nullable=False)
    region = Column(String(100), index=True, nullable=False, default="Punjab, Pakistan")
    version = Column(String(80))
    published_at = Column(DateTime(timezone=True))
    approved = Column(Boolean, nullable=False, default=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
