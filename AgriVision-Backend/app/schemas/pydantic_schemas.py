from pydantic import BaseModel, ConfigDict, Field as PydanticField
from datetime import datetime
from uuid import UUID
from typing import List, Optional

# --- Shared Base Models (for returning data) ---

class SensorReadingBase(BaseModel):
    # Mapping to Swift `SensorReading` struct
    value: float
    type: str # 'temperature', 'moisture', etc.
    unit: str
    timestamp: datetime
    
    # Optional fields for wide schema
    ph: Optional[float] = None
    ec: Optional[float] = None
    npk_n: Optional[float] = None
    npk_p: Optional[float] = None
    npk_k: Optional[float] = None

    model_config = ConfigDict(from_attributes=True)

# Pydantic model specifically designed for the database rows
class SensorReadingDB(BaseModel):
    time: datetime
    sensor_id: UUID
    temperature: Optional[float] = None
    moisture: Optional[float] = None
    humidity: Optional[float] = None
    ph: Optional[float] = None
    ec: Optional[float] = None
    npk_n: Optional[float] = None
    npk_p: Optional[float] = None
    npk_k: Optional[float] = None

    model_config = ConfigDict(from_attributes=True)

# --- Sensor Models ---

class SensorCreate(BaseModel):
    device_id: str
    name: Optional[str] = None
    sensor_type: str = "multi_sensor"

class SensorResponse(BaseModel):
    id: UUID
    field_id: UUID
    device_id: str
    name: Optional[str] = None
    sensor_type: str
    battery_level: Optional[float] = None
    last_seen: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)

# --- Field Models ---
# A basic geometry representation for the API: list of [lng, lat] pairs
class PointCoordinates(BaseModel):
    longitude: float
    latitude: float

class FieldCreate(BaseModel):
    name: str
    coordinates: List[PointCoordinates]
    area_ha: Optional[float] = None
    crop_type: Optional[str] = None
    plantation_date: Optional[datetime] = None
    expected_harvest_date: Optional[datetime] = None

class FieldWithSensorsCreate(FieldCreate):
    sensors: Optional[List[SensorCreate]] = []

class FieldResponse(BaseModel):
    id: UUID
    owner_id: UUID
    name: str
    coordinates: List[PointCoordinates] = PydanticField(default_factory=list)
    area_ha: Optional[float] = None
    created_at: datetime
    
    # Context Logic
    crop_type: Optional[str] = None
    plantation_date: Optional[datetime] = None
    expected_harvest_date: Optional[datetime] = None

    # Satellite Data
    agromonitory_poly_id: Optional[str] = None
    latest_ndvi: Optional[float] = None
    last_satellite_sync: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)

# --- User Models ---

class UserSchema(BaseModel):
    id: UUID
    firebase_uid: str
    email: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


# --- AI Recommendation Models ---

class RecommendationResponse(BaseModel):
    id: UUID
    field_id: UUID
    category: str
    priority: str
    advice: str
    confidence: Optional[float] = None
    status: str
    ndvi_at_generation: Optional[float] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
