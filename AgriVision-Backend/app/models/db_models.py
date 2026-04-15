from sqlalchemy import Column, String, Float, ForeignKey, DateTime, Integer
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import uuid
from geoalchemy2 import Geometry

from app.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    firebase_uid = Column(String, unique=True, index=True, nullable=False)
    email = Column(String, unique=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    fields = relationship("Field", back_populates="owner")

class Field(Base):
    __tablename__ = "fields"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    owner_id = Column(PG_UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    name = Column(String, nullable=False)
    
    # Context Logic
    crop_type = Column(String, nullable=True)
    plantation_date = Column(DateTime(timezone=True), nullable=True)
    expected_harvest_date = Column(DateTime(timezone=True), nullable=True)

    # Store field boundaries using PostGIS Geometry (Polygon, SRID 4326 for standard GPS coordinates)
    boundary = Column(Geometry('POLYGON', srid=4326), nullable=False)
    
    # Pre-computed area (e.g., in hectares)
    area_ha = Column(Float, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Satellite Sync Fields
    agromonitory_poly_id = Column(String, nullable=True)
    latest_ndvi = Column(Float, nullable=True)
    last_satellite_sync = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    owner = relationship("User", back_populates="fields")
    sensors = relationship("Sensor", back_populates="field", cascade="all, delete-orphan")
    recommendations = relationship("FieldRecommendation", back_populates="field", cascade="all, delete-orphan", order_by="desc(FieldRecommendation.created_at)")

class Sensor(Base):
    __tablename__ = "sensors"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    field_id = Column(PG_UUID(as_uuid=True), ForeignKey("fields.id", ondelete="CASCADE"), nullable=True)
    
    # The hardware ID of the ESP32 or other sensor unit
    device_id = Column(String, unique=True, index=True, nullable=False)
    
    # Friendly name assigned by the user
    name = Column(String, nullable=True)
    
    sensor_type = Column(String, default="multi_sensor") # e.g. "soil_multi", "weather_station"
    battery_level = Column(Float, nullable=True) # Percentage
    last_seen = Column(DateTime(timezone=True), nullable=True)

    # Note: We don't link directly to Readings via relationship because
    # Readings will be a TimescaleDB hypertable, and heavy joins are discouraged.
    # Instead, we just store sensor_id in the hypertable.

    # Relationships
    field = relationship("Field", back_populates="sensors")

class SensorReading(Base):
    __tablename__ = "sensor_readings"
    
    # In TimescaleDB, the primary key usually includes the time column
    # For SQLAlchemy, we just define the columns we need.
    
    time = Column(DateTime(timezone=True), primary_key=True, default=func.now())
    sensor_id = Column(PG_UUID(as_uuid=True), ForeignKey("sensors.id", ondelete="CASCADE"), primary_key=True)
    
    # Reading Values
    temperature = Column(Float, nullable=True)
    moisture = Column(Float, nullable=True)
    humidity = Column(Float, nullable=True)
    
    # Advanced Agri Metrics
    ph = Column(Float, nullable=True)
    ec = Column(Float, nullable=True)
    
    # NPK Values
    npk_n = Column(Float, nullable=True)
    npk_p = Column(Float, nullable=True)
    npk_k = Column(Float, nullable=True)
    
    # Additional readings can be added later


class FieldRecommendation(Base):
    """
    Stores AI-generated agronomic recommendations for each field.
    Populated by the AI Advisor background worker (runs every 4 hours).
    """
    __tablename__ = "field_recommendations"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    field_id = Column(PG_UUID(as_uuid=True), ForeignKey("fields.id", ondelete="CASCADE"), nullable=False)
    
    # e.g., "Irrigation", "Plant Health", "Weather Alert", "Fertilizer Window"
    category = Column(String, nullable=False)

    # "low", "medium", "high"
    priority = Column(String, nullable=False, default="medium")

    # The AI's full recommendation text
    advice = Column(String, nullable=False)

    # A value from 0.0 to 1.0 indicating how confident the AI is
    confidence = Column(Float, nullable=True)

    # Feedback loop: "pending", "implemented", "ignored"
    status = Column(String, default="pending")

    # Context snapshot used to generate this recommendation
    ndvi_at_generation = Column(Float, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationship
    field = relationship("Field", back_populates="recommendations")


class AIChatMessage(Base):
    """
    Stores conversational memory for the autonomous AI agent.
    Roles: 'user' or 'model' (Gemini standard)
    """
    __tablename__ = "ai_chat_messages"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    field_id = Column(PG_UUID(as_uuid=True), ForeignKey("fields.id", ondelete="CASCADE"), nullable=False)
    
    role = Column(String, nullable=False)
    content = Column(String, nullable=False)

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    field = relationship("Field", backref="chat_messages")
