import json
import asyncio
import logging
from datetime import datetime, timedelta
from sqlalchemy import func
from sqlalchemy.orm import Session
from geoalchemy2.functions import ST_AsGeoJSON, ST_X, ST_Y, ST_Centroid
from app.database import SessionLocal, engine
from app.models.db_models import Field, FieldRecommendation, Sensor, SensorReading
from app.services.agromonitoring_service import (
    create_polygon, get_ndvi_for_field, get_soil_data, get_weather_forecast
)

logger = logging.getLogger(__name__)


async def sync_satellite_data():
    """
    Periodic background task that fetches satellite NDVI and soil data 
    for all registered agricultural fields.
    """
    logger.info("Satellite Sync Worker: Initializing background loop...")
    
    while True:
        try:
            db: Session = SessionLocal()
            try:
                fields = db.query(Field).all()
                logger.info(f"Satellite Sync Worker: Syncing health data for {len(fields)} fields...")
                
                for field in fields:
                    # 1. Register with Agromonitoring if not already done
                    if not field.agromonitory_poly_id:
                        logger.info(f"Registering field '{field.name}' with Agromonitoring satellite service...")
                        
                        geojson_str = db.query(ST_AsGeoJSON(Field.boundary)).filter(Field.id == field.id).scalar()
                        
                        if geojson_str:
                            geojson_dict = json.loads(geojson_str)
                            feature_geojson = {
                                "type": "Feature",
                                "properties": {},
                                "geometry": geojson_dict
                            }
                            
                            poly_id = await create_polygon(field.name, feature_geojson)
                            if poly_id:
                                field.agromonitory_poly_id = poly_id
                                logger.info(f"Field '{field.name}' registered successfully. PolyID: {poly_id}")
                            else:
                                logger.warning(f"Could not register field '{field.name}'. Will retry next cycle.")
                    
                    # 2. Fetch NDVI if we have a poly_id
                    if field.agromonitory_poly_id:
                        ndvi_data = await get_ndvi_for_field(field.agromonitory_poly_id)
                        
                        if ndvi_data:
                            field.latest_ndvi = ndvi_data.get("ndvi", 0.0)
                            field.last_satellite_sync = datetime.now()
                            logger.info(f"Updated NDVI for '{field.name}': {field.latest_ndvi}")
                
                db.commit()
                logger.info("Satellite Sync Worker: Sync cycle complete.")
                
            except Exception as e:
                logger.error(f"Satellite Sync Worker: Database error during sync: {e}")
                db.rollback()
            finally:
                db.close()
                
            await asyncio.sleep(3600)  # Run every 1 hour 
            
        except asyncio.CancelledError:
            logger.info("Satellite Sync Worker: Background task shutting down.")
            break
        except Exception as e:
            logger.error(f"Satellite Sync Worker: Unexpected error: {e}")
            await asyncio.sleep(60)


async def run_ai_for_field(field: Field, db: Session):
    """
    Runs the full AI analysis pipeline for a single field.
    Fetches multi-modal context and generates Gemini recommendations.
    This is called both by the scheduled loop and by the on-demand /refresh endpoint.
    """
    from app.services.ai_advisor_service import generate_field_recommendations

    try:
        # 1. Get NDVI trend (simple 2-point comparison for now)
        ndvi = field.latest_ndvi
        ndvi_trend = "stable"
        if ndvi is not None:
            if ndvi < 0.25:
                ndvi_trend = "critically low"
            elif ndvi < 0.4:
                ndvi_trend = "below average — possible stress"
            elif ndvi > 0.6:
                ndvi_trend = "healthy and vigorous"
            else:
                ndvi_trend = "moderate"

        # 2. Get satellite soil data
        soil_data = None
        if field.agromonitory_poly_id:
            soil_data = await get_soil_data(field.agromonitory_poly_id)

        # 3. Get field centroid coordinates for weather fetch
        centroid_wkt = db.query(ST_Centroid(Field.boundary)).filter(Field.id == field.id).scalar()
        lat, lon = None, None
        weather_data = None
        if centroid_wkt:
            # ST_Centroid returns a geometry; extract X (lon) and Y (lat) 
            lon_val = db.query(ST_X(ST_Centroid(Field.boundary))).filter(Field.id == field.id).scalar()
            lat_val = db.query(ST_Y(ST_Centroid(Field.boundary))).filter(Field.id == field.id).scalar()
            if lat_val and lon_val:
                lat, lon = float(lat_val), float(lon_val)
                weather_data = await get_weather_forecast(lat, lon)

        # 4. Aggregate ESP32 sensor readings from the last 24 hours
        sensor_summary = None
        sensors_for_field = db.query(Sensor).filter(Sensor.field_id == field.id).all()
        if sensors_for_field:
            sensor_ids = [s.id for s in sensors_for_field]
            cutoff = datetime.utcnow() - timedelta(hours=24)
            readings = (
                db.query(SensorReading)
                .filter(
                    SensorReading.sensor_id.in_(sensor_ids),
                    SensorReading.time >= cutoff
                )
                .all()
            )
            if readings:
                temps = [r.temperature for r in readings if r.temperature is not None]
                moistures = [r.moisture for r in readings if r.moisture is not None]
                humidities = [r.humidity for r in readings if r.humidity is not None]
                sensor_summary = {
                    "sensor_count": len(sensors_for_field),
                    "reading_count": len(readings),
                    "avg_temp": round(sum(temps) / len(temps), 1) if temps else None,
                    "avg_moisture": round(sum(moistures) / len(moistures), 1) if moistures else None,
                    "avg_humidity": round(sum(humidities) / len(humidities), 1) if humidities else None,
                }

        # 5. Call the AI Brain
        recommendations = await generate_field_recommendations(
            field_name=field.name,
            area_ha=field.area_ha or 0.0,
            ndvi=ndvi,
            ndvi_trend=ndvi_trend,
            soil_data=soil_data,
            sensor_summary=sensor_summary,
            weather=weather_data
        )

        # 6. Delete old recommendations for this field (keep DB clean)
        db.query(FieldRecommendation).filter(FieldRecommendation.field_id == field.id).delete()

        # 7. Persist the new recommendations
        for rec in recommendations:
            db_rec = FieldRecommendation(
                field_id=field.id,
                category=rec.get("category", "General"),
                priority=rec.get("priority", "medium"),
                advice=rec.get("advice", ""),
                confidence=rec.get("confidence"),
                ndvi_at_generation=ndvi
            )
            db.add(db_rec)

        db.commit()
        logger.info(f"AI Advisor: Saved {len(recommendations)} recommendations for '{field.name}'")

    except Exception as e:
        logger.error(f"AI Advisor: Failed to generate recommendations for '{field.name}': {e}")
        db.rollback()


async def ai_reasoning_loop():
    """
    Periodic background task that runs the AI advisor for all fields.
    Executes every 4 hours.
    """
    logger.info("AI Advisor Worker: Initializing background loop...")
    # Initial delay — let satellite sync run first to ensure NDVI is fresh
    await asyncio.sleep(30)

    while True:
        try:
            db: Session = SessionLocal()
            try:
                fields = db.query(Field).all()
                logger.info(f"AI Advisor Worker: Running analysis for {len(fields)} fields...")
                for field in fields:
                    await run_ai_for_field(field, db)
                logger.info("AI Advisor Worker: Analysis cycle complete.")
            except Exception as e:
                logger.error(f"AI Advisor Worker: Error during loop: {e}")
                db.rollback()
            finally:
                db.close()

            await asyncio.sleep(4 * 3600)  # Run every 4 hours

        except asyncio.CancelledError:
            logger.info("AI Advisor Worker: Background task shutting down.")
            break
        except Exception as e:
            logger.error(f"AI Advisor Worker: Unexpected error: {e}")
            await asyncio.sleep(300)


def start_satellite_sync_worker():
    """Starts the satellite sync loop in the background."""
    return asyncio.create_task(sync_satellite_data())


def start_ai_reasoning_worker():
    """Starts the AI advisor reasoning loop in the background."""
    return asyncio.create_task(ai_reasoning_loop())
