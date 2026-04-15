import logging
import firebase_admin
from firebase_admin import credentials
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.database import engine, Base
from app.api import fields, sensors, recommendations, chat
from app.services.mqtt_service import run_in_background

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Firebase Admin SDK
try:
    cred = credentials.Certificate(settings.FIREBASE_SERVICE_ACCOUNT_PATH)
    firebase_admin.initialize_app(cred)
    logger.info("Firebase Admin initialized successfully.")
except Exception as e:
    logger.error(f"Error initializing Firebase Admin: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Handles startup and shutdown events.
    - On startup: creates DB tables and starts the MQTT bridge.
    - On shutdown: clean up resources (if needed).
    """
    logger.info("AgriVision API starting up...")
    
    # Wait for database to be ready (Docker race condition fix)
    retries = 5
    for i in range(retries):
        try:
            logger.info(f"Attempting to connect to database (Attempt {i+1}/{retries})...")
            # Enable required extensions BEFORE creating tables
            from sqlalchemy import text
            with engine.connect() as conn:
                try:
                    conn.execute(text("CREATE EXTENSION IF NOT EXISTS postgis;"))
                    conn.execute(text("CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;"))
                    conn.commit()
                    logger.info("PostGIS and TimescaleDB extensions enabled.")
                except Exception as ext_err:
                    logger.warning(f"Failed to create extensions (might require superuser): {ext_err}")

            # Create all database tables on first run
            Base.metadata.create_all(bind=engine)
            logger.info("Database tables verified.")
            
            # Patch existing sensors table just in case it was created with NOT NULL field_id previously
            with engine.connect() as conn:
                try:
                    conn.execute(text("ALTER TABLE sensors ALTER COLUMN field_id DROP NOT NULL;"))
                    conn.commit()
                    logger.info("Ensured sensors.field_id is nullable.")
                except Exception as patch_err:
                    logger.warning(f"Could not patch sensors table: {patch_err}")

            # Setup TimescaleDB hypertable if sensor_readings table was just created
            with engine.connect() as conn:
                try:
                    conn.execute(text("SELECT create_hypertable('sensor_readings', 'time', if_not_exists => TRUE);"))
                    conn.commit()
                    logger.info("TimescaleDB hypertable configured for sensor_readings.")
                except Exception as ht_err:
                    logger.warning(f"Could not setup hypertable (perhaps it already exists): {ht_err}")
                    
            break
        except Exception as e:
            logger.warning(f"Database connection failed: {e}")
            if i == retries - 1:
                logger.error("Could not connect to database after maximum retries.")
                raise e
            logger.info("Waiting 3 seconds before retrying...")
            import time
            time.sleep(3)
            
    # Start MQTT listener in background thread
    run_in_background()
    logger.info("MQTT Bridge is running.")
    
    # Start Satellite Sync background task
    from app.services.scheduler import start_satellite_sync_worker, start_ai_reasoning_worker
    start_satellite_sync_worker()
    logger.info("Satellite Sync Worker started.")
    
    # Start AI Advisor reasoning loop
    start_ai_reasoning_worker()
    logger.info("AI Advisor Worker started.")
    
    yield
    logger.info("AgriVision API shutting down.")


app = FastAPI(
    title="AgriVision API",
    description="The 'Brain' of AgriVision — Satellite Data, Live Sensor Ingestion, and AI-Ready Predictions.",
    version="0.1.0",
    lifespan=lifespan
)

# Configure CORS to allow the iOS app and local development tools to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict in production to your app's domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register API routers
app.include_router(fields.router)
app.include_router(sensors.router)
app.include_router(recommendations.router)
app.include_router(chat.router)


@app.get("/", tags=["Health"])
async def root():
    return {"message": "AgriVision API — The Brain is Online 🌱"}


@app.get("/health", tags=["Health"])
async def health_check():
    return {"status": "healthy", "version": "0.1.0"}
