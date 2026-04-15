"""
Agromonitoring API Service - "The Brain" External Data Source

This service integrates with the Agromonitoring API (https://agromonitoring.com)
to fetch satellite imagery, NDVI (plant health), soil data, and weather
for each registered field's GPS polygon.

When you have your API key, replace AGROMONITORING_API_KEY in your environment.
"""

import json
import os
import logging
import httpx
import time
from datetime import datetime
from typing import Optional, Dict, Any, Tuple
from functools import wraps

logger = logging.getLogger(__name__)

AGROMONITORING_API_KEY = os.getenv("AGROMONITORING_API_KEY", "")
BASE_URL = "https://api.agromonitoring.com/agro/1.0"

# --- Simple Async TTL Cache to prevent Free-Tier Rate Limits ---
_api_cache: Dict[Tuple, Tuple[float, Any]] = {}
CACHE_TTL_SECONDS = 3600 * 6  # 6 hours cache for non-urgent endpoints

def async_ttl_cache(ttl_seconds=CACHE_TTL_SECONDS):
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Create a unique cache key based on function name, args, and kwargs
            # (Ignoring non-hashable kwargs for simplicity if any, but our args are str/float)
            key = (func.__name__, args, frozenset(kwargs.items()))
            now = time.time()
            if key in _api_cache:
                timestamp, result = _api_cache[key]
                if now - timestamp < ttl_seconds:
                    logger.debug(f"Cache hit for {func.__name__} - saving free tier limits.")
                    return result
            
            result = await func(*args, **kwargs)
            
            # Cache the result if we didn't get an explicit None/Failure rate limit
            # But we also cache None for a short time to avoid hammering failing endpoints
            _api_cache[key] = (now, result)
            return result
        return wrapper
    return decorator


async def create_polygon(name: str, geojson: Dict[str, Any]) -> Optional[str]:
    """
    Registers a new field polygon with the Agromonitoring API.
    Returns the `polygon_id` (e.g. '60b752c9b...').
    """
    if not AGROMONITORING_API_KEY:
        logger.warning("AGROMONITORING_API_KEY not set. Cannot create real polygon.")
        return None

    # Agromonitoring requires name and geo_json
    payload = {
        "name": name,
        "geo_json": geojson
    }

    async with httpx.AsyncClient() as client:
        try:
            resp = await client.post(
                f"{BASE_URL}/polygons",
                params={"appid": AGROMONITORING_API_KEY},
                json=payload,
                timeout=10.0
            )
            
            if resp.status_code == 400 and "duplicated" in resp.text:
                logger.warning(f"Polygon '{name}' already exists in Agromonitoring. Fetching existing ID...")
                # Search for the existing polygon by name
                list_resp = await client.get(
                    f"{BASE_URL}/polygons",
                    params={"appid": AGROMONITORING_API_KEY}
                )
                if list_resp.status_code == 200:
                    for poly in list_resp.json():
                        if poly.get("name") == name:
                            return poly.get("id")
                return None
                
            resp.raise_for_status()
            data = resp.json()
            return data.get("id")
        except Exception as e:
            logger.error(f"Failed to create Agromonitoring polygon: {e}")
            return None


async def get_ndvi_for_field(polygon_id: str) -> Optional[dict]:
    """
    Fetch the latest NDVI satellite image stats for a polygon.
    NDVI ranges from -1 to 1. Healthy crops are 0.2–0.9.
    """
    if not AGROMONITORING_API_KEY:
        logger.warning("AGROMONITORING_API_KEY not set. Returning mock data.")
        return {"ndvi": 0.65, "source": "mock", "polygon_id": polygon_id}

    async with httpx.AsyncClient() as client:
        try:
            # We use the history endpoint to get the most recent data point
            resp = await client.get(
                f"{BASE_URL}/ndvi/history",
                params={
                    "polyid": polygon_id,
                    "appid": AGROMONITORING_API_KEY,
                    "start": int(datetime.now().timestamp()) - (30 * 86400), # Last 30 days
                    "end": int(datetime.now().timestamp())
                }
            )
            resp.raise_for_status()
            history = resp.json()
            
            if history and len(history) > 0:
                # Return the most recent record
                return {
                    "ndvi": history[-1].get("data", {}).get("mean", 0.0),
                    "source": "satellite",
                    "timestamp": history[-1].get("dt")
                }
            return None
        except Exception as e:
            logger.error(f"Error fetching NDVI for {polygon_id}: {e}")
            return None


async def get_soil_data(polygon_id: str) -> Optional[dict]:
    """
    Fetch current soil moisture and temperature from satellite data.
    Returns a structured dict ready to be consumed by the AI prompt builder.
    """
    if not AGROMONITORING_API_KEY:
        return {"moisture": 0.35, "t0": 295.1, "t10": 293.5, "source": "mock"}

    async with httpx.AsyncClient() as client:
        try:
            resp = await client.get(
                f"{BASE_URL}/soil",
                params={"polyid": polygon_id, "appid": AGROMONITORING_API_KEY},
                timeout=10.0
            )
            resp.raise_for_status()
            data = resp.json()
            # t0 = surface temp, t10 = 10cm depth temp (in Kelvin, convert to Celsius)
            return {
                "moisture": data.get("moisture"),
                "surface_temp_c": round(data.get("t0", 273.15) - 273.15, 1),
                "depth_temp_c": round(data.get("t10", 273.15) - 273.15, 1),
                "source": "satellite"
            }
        except Exception as e:
            logger.error(f"Error fetching soil data for {polygon_id}: {e}")
            return None


async def get_weather_forecast(lat: float, lon: float) -> Optional[dict]:
    """
    Fetch a 7-day weather forecast for specific field coordinates.
    Returns a structured dict ready to be consumed by the AI prompt builder.
    """
    if not AGROMONITORING_API_KEY:
        return {
            "current": {"temp_c": 30.0, "humidity": 60, "description": "Partly cloudy"},
            "forecast_days": [
                {"day": 1, "temp_max_c": 32, "rain_mm": 0, "description": "Sunny"},
                {"day": 2, "temp_max_c": 31, "rain_mm": 2.1, "description": "Light rain"},
                {"day": 3, "temp_max_c": 28, "rain_mm": 12.5, "description": "Heavy rain"},
            ],
            "source": "mock"
        }

    async with httpx.AsyncClient() as client:
        try:
            # Current weather
            current_resp = await client.get(
                f"{BASE_URL}/weather",
                params={"lat": lat, "lon": lon, "appid": AGROMONITORING_API_KEY},
                timeout=10.0
            )
            current_resp.raise_for_status()
            current = current_resp.json()

            # 7-day forecast
            forecast_resp = await client.get(
                f"{BASE_URL}/weather/forecast",
                params={"lat": lat, "lon": lon, "appid": AGROMONITORING_API_KEY},
                timeout=10.0
            )
            forecast_resp.raise_for_status()
            forecast_data = forecast_resp.json()

            # Aggregate daily summaries from hourly entries
            from collections import defaultdict
            daily = defaultdict(lambda: {"rain_mm": 0, "temps": [], "description": ""})
            for entry in forecast_data.get("list", []):
                day_key = entry.get("dt_txt", "")[:10]
                daily[day_key]["temps"].append(entry.get("main", {}).get("temp", 273.15) - 273.15)
                daily[day_key]["rain_mm"] += entry.get("rain", {}).get("3h", 0)
                daily[day_key]["description"] = entry.get("weather", [{}])[0].get("description", "")

            forecast_days = []
            for i, (day_key, day_data) in enumerate(sorted(daily.items())[:7]):
                forecast_days.append({
                    "date": day_key,
                    "temp_max_c": round(max(day_data["temps"]), 1) if day_data["temps"] else None,
                    "temp_min_c": round(min(day_data["temps"]), 1) if day_data["temps"] else None,
                    "rain_mm": round(day_data["rain_mm"], 1),
                    "description": day_data["description"]
                })

            return {
                "current": {
                    "temp_c": round(current.get("main", {}).get("temp", 273.15) - 273.15, 1),
                    "humidity": current.get("main", {}).get("humidity"),
                    "description": current.get("weather", [{}])[0].get("description", "")
                },
                "forecast_days": forecast_days,
                "source": "satellite"
            }
        except Exception as e:
            logger.error(f"Error fetching weather for {lat},{lon}: {e}")
            return None


@async_ttl_cache(ttl_seconds=86400) # Cache for 24 hours to aggressively protect free tier
async def get_satellite_imagery_urls(polygon_id: str, start_time: int, end_time: int) -> Optional[dict]:
    """
    Search for satellite imagery metadata and tile links over a specific time range.
    """
    if not AGROMONITORING_API_KEY:
        return None

    async with httpx.AsyncClient() as client:
        try:
            resp = await client.get(
                f"{BASE_URL}/image/search",
                params={
                    "polyid": polygon_id,
                    "start": start_time,
                    "end": end_time,
                    "appid": AGROMONITORING_API_KEY
                },
                timeout=10.0
            )
            resp.raise_for_status()
            return {"images": resp.json()}
        except Exception as e:
            logger.error(f"Error searching imagery for {polygon_id}: {e}")
            return None

@async_ttl_cache(ttl_seconds=86400)
async def get_accumulated_temperature(lat: float, lon: float, start_time: int, end_time: int, threshold: float = 283.15) -> Optional[list]:
    """
    Get accumulated temperature (Growing Degree Days equivalent) for a location.
    """
    if not AGROMONITORING_API_KEY:
        return None
        
    async with httpx.AsyncClient() as client:
        try:
            resp = await client.get(
                f"{BASE_URL}/weather/history/accumulated_temperature",
                params={
                    "lat": lat, "lon": lon,
                    "start": start_time, "end": end_time,
                    "threshold": threshold,
                    "appid": AGROMONITORING_API_KEY
                },
                timeout=10.0
            )
            # Free tier might reject this (402/403)
            if resp.status_code in [402, 403]:
                return None
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            logger.debug(f"Accumulated temp not available or error for {lat},{lon}: {e}")
            return None

@async_ttl_cache(ttl_seconds=86400)
async def get_accumulated_precipitation(lat: float, lon: float, start_time: int, end_time: int) -> Optional[list]:
    """
    Get accumulated precipitation for a location.
    """
    if not AGROMONITORING_API_KEY:
        return None
        
    async with httpx.AsyncClient() as client:
        try:
            resp = await client.get(
                f"{BASE_URL}/weather/history/accumulated_precipitation",
                params={
                    "lat": lat, "lon": lon,
                    "start": start_time, "end": end_time,
                    "appid": AGROMONITORING_API_KEY
                },
                timeout=10.0
            )
            if resp.status_code in [402, 403]:
                return None
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            logger.debug(f"Accumulated precip not available or error: {e}")
            return None

@async_ttl_cache(ttl_seconds=3600)
async def get_current_uvi(polygon_id: str) -> Optional[dict]:
    """
    Get current UV Index for a polygon.
    """
    if not AGROMONITORING_API_KEY:
        return {"uvi": 4.5}
        
    async with httpx.AsyncClient() as client:
        try:
            resp = await client.get(
                f"{BASE_URL}/uvi",
                params={"polyid": polygon_id, "appid": AGROMONITORING_API_KEY},
                timeout=10.0
            )
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            logger.debug(f"Current UV not available for {polygon_id}: {e}")
            return None

@async_ttl_cache(ttl_seconds=3600*6)
async def get_forecast_uvi(polygon_id: str) -> Optional[list]:
    """
    Get forecast UV Index for a polygon.
    """
    if not AGROMONITORING_API_KEY:
        return None
        
    async with httpx.AsyncClient() as client:
        try:
            resp = await client.get(
                f"{BASE_URL}/uvi/forecast",
                params={"polyid": polygon_id, "appid": AGROMONITORING_API_KEY},
                timeout=10.0
            )
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            logger.debug(f"Forecast UV not available for {polygon_id}: {e}")
            return None

@async_ttl_cache(ttl_seconds=86400)
async def get_historical_uvi(polygon_id: str, start_time: int, end_time: int) -> Optional[list]:
    """
    Get historical UV Index for a polygon.
    """
    if not AGROMONITORING_API_KEY:
        return None
        
    async with httpx.AsyncClient() as client:
        try:
            resp = await client.get(
                f"{BASE_URL}/uvi/history",
                params={"polyid": polygon_id, "start": start_time, "end": end_time, "appid": AGROMONITORING_API_KEY},
                timeout=10.0
            )
            if resp.status_code in [402, 403]:
                return None
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            logger.debug(f"Historical UV not available: {e}")
            return None

@async_ttl_cache(ttl_seconds=86400)
async def get_historical_weather(lat: float, lon: float, start_time: int, end_time: int) -> Optional[list]:
    """
    Get historical weather. NOTE: Historically paid tier, so we catch 402/403.
    """
    if not AGROMONITORING_API_KEY:
        return None
        
    async with httpx.AsyncClient() as client:
        try:
            resp = await client.get(
                f"{BASE_URL}/weather/history",
                params={"lat": lat, "lon": lon, "start": start_time, "end": end_time, "appid": AGROMONITORING_API_KEY},
                timeout=10.0
            )
            if resp.status_code in [402, 403]:
                return None
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            logger.debug(f"Historical weather not available: {e}")
            return None

@async_ttl_cache(ttl_seconds=86400)
async def get_historical_soil(polygon_id: str, start_time: int, end_time: int) -> Optional[dict]:
    """
    Get historical soil data. NOTE: Historically paid tier, so we catch 402/403.
    """
    if not AGROMONITORING_API_KEY:
        return None
        
    async with httpx.AsyncClient() as client:
        try:
            resp = await client.get(
                f"{BASE_URL}/soil/history",
                params={"polyid": polygon_id, "start": start_time, "end": end_time, "appid": AGROMONITORING_API_KEY},
                timeout=10.0
            )
            if resp.status_code in [402, 403]:
                return None
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            logger.debug(f"Historical soil not available: {e}")
            return None
