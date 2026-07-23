import math
import re
from datetime import datetime
from typing import Annotated, Any, Literal, Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field as PydanticField, field_validator, model_validator


SafeName = Annotated[str, PydanticField(min_length=1, max_length=100)]


def clean_text(value: str) -> str:
    value = " ".join(value.strip().split())
    if any(ord(char) < 32 for char in value):
        raise ValueError("Control characters are not allowed")
    return value


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class PointCoordinates(StrictModel):
    longitude: Annotated[float, PydanticField(ge=-180, le=180)]
    latitude: Annotated[float, PydanticField(ge=-90, le=90)]


class SensorCreate(StrictModel):
    device_id: Annotated[str, PydanticField(min_length=3, max_length=100, pattern=r"^[A-Za-z0-9._:-]+$")]
    name: Optional[Annotated[str, PydanticField(max_length=100)]] = None
    sensor_type: Annotated[str, PydanticField(min_length=1, max_length=50, pattern=r"^[A-Za-z0-9_-]+$")] = "multi_sensor"

    _clean_name = field_validator("name")(lambda value: clean_text(value) if value else value)


class SensorResponse(BaseModel):
    id: UUID
    field_id: Optional[UUID]
    device_id: str
    name: Optional[str]
    sensor_type: str
    battery_level: Optional[float]
    last_seen: Optional[datetime]
    model_config = ConfigDict(from_attributes=True)


class SensorPairRequest(StrictModel):
    device_id: Annotated[str, PydanticField(min_length=3, max_length=100, pattern=r"^[A-Za-z0-9._:-]+$")]


class SensorPairResponse(BaseModel):
    is_paired: Literal[True] = True
    message: str
    sensor: SensorResponse


class FieldCreate(StrictModel):
    name: SafeName
    coordinates: Annotated[list[PointCoordinates], PydanticField(min_length=3, max_length=500)]
    area_ha: Optional[Annotated[float, PydanticField(gt=0, le=100000)]] = None
    crop_type: Optional[Annotated[str, PydanticField(max_length=80)]] = None
    plantation_date: Optional[datetime] = None
    expected_harvest_date: Optional[datetime] = None

    _clean_name = field_validator("name")(clean_text)
    _clean_crop = field_validator("crop_type")(lambda value: clean_text(value) if value else value)

    @model_validator(mode="after")
    def validate_boundary_and_dates(self):
        points = [(point.longitude, point.latitude) for point in self.coordinates]
        if len(set(points)) < 3:
            raise ValueError("A field boundary requires at least three distinct coordinates")
        for first, second in zip(points, points[1:] + points[:1]):
            if first == second:
                raise ValueError("Adjacent boundary coordinates must be distinct")
        if self.plantation_date and self.expected_harvest_date and self.expected_harvest_date <= self.plantation_date:
            raise ValueError("Expected harvest date must be after plantation date")
        return self


class FieldWithSensorsCreate(FieldCreate):
    sensors: list[SensorCreate] = PydanticField(default_factory=list, max_length=20)


class FieldUpdate(StrictModel):
    name: Optional[SafeName] = None
    crop_type: Optional[Annotated[str, PydanticField(max_length=80)]] = None
    expected_harvest_date: Optional[datetime] = None

    _clean_name = field_validator("name")(lambda value: clean_text(value) if value else value)
    _clean_crop = field_validator("crop_type")(lambda value: clean_text(value) if value else value)


class FieldResponse(BaseModel):
    id: UUID
    owner_id: UUID
    name: str
    coordinates: list[PointCoordinates] = PydanticField(default_factory=list)
    area_ha: float
    status: str
    archived_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime
    crop_type: Optional[str] = None
    plantation_date: Optional[datetime] = None
    expected_harvest_date: Optional[datetime] = None
    agromonitoring_polygon_id: Optional[str] = None
    agro_status: str
    agro_error: Optional[str] = None
    agro_retryable: bool
    latest_ndvi: Optional[float] = None
    last_satellite_sync: Optional[datetime] = None
    model_config = ConfigDict(from_attributes=True)


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


class RecommendationResponse(BaseModel):
    id: UUID
    field_id: UUID
    category: str
    priority: str
    advice: str
    rationale: Optional[str] = None
    confidence: Optional[float] = None
    confidence_reason: Optional[str] = None
    evidence: Optional[Any] = None
    safety_level: str = "guarded"
    requires_expert_confirmation: bool = False
    status: str
    ndvi_at_generation: Optional[float] = None
    created_at: datetime
    expires_at: Optional[datetime] = None
    outcome: Optional[str] = None
    outcome_notes: Optional[str] = None
    model_config = ConfigDict(from_attributes=True)


class RecommendationFeedback(StrictModel):
    status: Literal["pending", "implemented", "ignored"]


class RecommendationOutcome(StrictModel):
    outcome: Literal["useful", "ineffective", "harmful"]
    notes: Optional[Annotated[str, PydanticField(max_length=1000)]] = None

    _clean_notes = field_validator("notes")(lambda value: clean_text(value) if value else value)


class ChatMessageRequest(StrictModel):
    message: Annotated[str, PydanticField(min_length=1, max_length=2000)]

    _clean_message = field_validator("message")(clean_text)


class ChatAttachmentResponse(BaseModel):
    id: UUID
    mime_type: str
    byte_size: int
    width: int
    height: int
    url: str


class ChatMessageResponse(BaseModel):
    id: UUID
    role: Literal["user", "model"]
    content: str
    status: Literal["completed", "failed", "processing"] = "completed"
    attachments: list[ChatAttachmentResponse] = PydanticField(default_factory=list)
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


class ChatTurnResponse(BaseModel):
    user_message: ChatMessageResponse
    assistant_message: ChatMessageResponse


class UserSchema(BaseModel):
    id: UUID
    firebase_uid: str
    email: Optional[str]
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


class SessionBootstrapResponse(BaseModel):
    user: UserSchema
    fields: list[FieldResponse]
    active_field_limit: int = 5
    active_field_count: int


class ErrorBody(BaseModel):
    code: str
    message: str
    details: Optional[Any] = None
    retryable: bool = False
    request_id: str


class ErrorEnvelope(BaseModel):
    error: ErrorBody
