from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta, timezone
from typing import List

from app.database import get_db
from app.models.db_models import Sensor
from app.schemas.pydantic_schemas import SensorResponse

router = APIRouter(prefix="/api/sensors", tags=["Sensors"])

@router.get("/verify/{device_id}", response_model=dict)
def verify_sensor_connection(
    device_id: str,
    db: Session = Depends(get_db)
):
    """
    Check if a sensor with the given device_id is active.
    Success criteria: Device exists and has a 'last_seen' heartbeat in the last 60 minutes.
    """
    sensor = db.query(Sensor).filter(Sensor.device_id == device_id).first()
    
    if not sensor:
        # For the development demo, we can also return Success if the MQTT logs
        # haven't registered the device yet but we want to allow pairing.
        # However, following the requirement to 'Verify before final submission':
        return {
            "is_verified": False,
            "message": "Hardware ID not found in system. Please ensure your device is powered and connected."
        }
    
    # Check heartbeat
    if sensor.last_seen:
        cutoff = datetime.now(timezone.utc) - timedelta(minutes=60)
        if sensor.last_seen >= cutoff:
            return {
                "is_verified": True,
                "name": sensor.name,
                "last_seen": sensor.last_seen,
                "message": "Hardware verified and active."
            }
            
    return {
        "is_verified": False,
        "message": "Sensor found but no recent heartbeat detected. Check power/serial bridge."
    }
