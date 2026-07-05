from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import text
from typing import List
from uuid import UUID
import uuid
import logging

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

from app.database import get_db
from app.models.db_models import Field, User, Sensor
from app.schemas.pydantic_schemas import FieldCreate, FieldResponse, FieldWithSensorsCreate
from app.core.auth import get_current_user
from geoalchemy2.functions import ST_Centroid, ST_X, ST_Y
from app.services.agromonitoring_service import get_soil_data, get_weather_forecast

router = APIRouter(prefix="/api/fields", tags=["Fields"])


def coordinates_to_wkt(coordinates) -> str:
    """Convert a list of PointCoordinates to a WKT POLYGON string."""
    # WKT polygon needs the first point repeated at the end to close the ring
    points = [f"{pt.longitude} {pt.latitude}" for pt in coordinates]
    # Close the polygon
    points.append(points[0])
    return f"POLYGON(({', '.join(points)}))"


@router.post("/", response_model=FieldResponse, status_code=status.HTTP_201_CREATED)
def create_field(
    field_data: FieldWithSensorsCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Save a new field boundary drawn on the map, optionally associating IoT sensors.
    """
    if len(field_data.coordinates) < 3:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="A field boundary requires at least 3 coordinates."
        )

    # Convert coordinates to WKT format for PostGIS
    wkt_polygon = coordinates_to_wkt(field_data.coordinates)

    new_field = Field(
        owner_id=current_user.id,
        name=field_data.name,
        boundary=f"SRID=4326;{wkt_polygon}",
        area_ha=field_data.area_ha,
        crop_type=field_data.crop_type,
        plantation_date=field_data.plantation_date,
        expected_harvest_date=field_data.expected_harvest_date
    )
    db.add(new_field)
    db.flush() # Get the new_field.id without committing yet

    # Create or associate sensors if provided
    if field_data.sensors:
        for sensor_data in field_data.sensors:
            # Check if sensor already exists (auto-discovered)
            existing_sensor = db.query(Sensor).filter(Sensor.device_id == sensor_data.device_id).first()
            
            if existing_sensor:
                existing_sensor.field_id = new_field.id
                existing_sensor.name = sensor_data.name or existing_sensor.name
                existing_sensor.sensor_type = sensor_data.sensor_type or existing_sensor.sensor_type
                logger.info(f"Field API: Linked existing sensor '{sensor_data.device_id}' to field '{new_field.id}'")
            else:
                new_sensor = Sensor(
                    field_id=new_field.id,
                    device_id=sensor_data.device_id,
                    name=sensor_data.name,
                    sensor_type=sensor_data.sensor_type
                )
                db.add(new_sensor)
                logger.info(f"Field API: Created new sensor record for '{sensor_data.device_id}'")

    db.commit()
    db.refresh(new_field)
    return new_field


@router.get("/", response_model=List[FieldResponse])
def get_fields(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get all fields for the authenticated user."""
    fields = db.query(Field).filter(Field.owner_id == current_user.id).all()
    return fields


@router.get("/{field_id}", response_model=FieldResponse)
def get_field(
    field_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get a specific field by ID."""
    field = db.query(Field).filter(Field.id == field_id, Field.owner_id == current_user.id).first()
    if not field:
        raise HTTPException(status_code=404, detail="Field not found")
    return field


@router.delete("/{field_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_field(
    field_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete a field by ID."""
    field = db.query(Field).filter(Field.id == field_id, Field.owner_id == current_user.id).first()
    if not field:
        raise HTTPException(status_code=404, detail="Field not found")
    db.delete(field)
    db.commit()


@router.get("/{field_id}/weather-soil/", response_model=dict)
async def get_field_weather_soil(
    field_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Fetch satellite-based soil moisture/temperature and 7-day weather forecast 
    for the specific field.
    """
    field = db.query(Field).filter(Field.id == field_id, Field.owner_id == current_user.id).first()
    if not field:
        raise HTTPException(status_code=404, detail="Field not found")

    # Get centroid coordinates for weather
    lon_val = db.query(ST_X(ST_Centroid(Field.boundary))).filter(Field.id == field_id).scalar()
    lat_val = db.query(ST_Y(ST_Centroid(Field.boundary))).filter(Field.id == field_id).scalar()
    
    weather_data = None
    if lat_val and lon_val:
        weather_data = await get_weather_forecast(float(lat_val), float(lon_val))

    soil_data = None
    if field.agromonitory_poly_id:
        soil_data = await get_soil_data(field.agromonitory_poly_id)

    return {
        "field_id": field_id,
        "soil": soil_data or {
            "moisture": 0.0,
            "surface_temp_c": 0.0,
            "depth_temp_c": 0.0,
            "source": "empty"
        },
        "weather": weather_data or {
            "current": {"temp_c": 0.0, "humidity": 0, "description": "Unknown"},
            "forecast_days": [],
            "source": "empty"
        }
    }
