import os
from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    PROJECT_NAME: str = "AgriVision API"
    
    # Database
    DATABASE_URL: str = os.getenv("DATABASE_URL", "postgresql://admin:password@db:5432/agrivision")
    
    # Firebase
    FIREBASE_SERVICE_ACCOUNT_PATH: str = os.getenv(
        "FIREBASE_SERVICE_ACCOUNT_PATH", 
        "/app/firebase-credentials.json"
    )
    
    # MQTT
    MQTT_BROKER: str = os.getenv("MQTT_BROKER", "mqtt")
    MQTT_PORT: int = int(os.getenv("MQTT_PORT", 1883))

settings = Settings()
