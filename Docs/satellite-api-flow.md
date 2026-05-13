# Satellite APIs and Data Flow

This document details the implementation of the satellite integrations (Agromonitoring API) in the AgriVision-Backend.

## Are They Working Properly?
Yes, they are implemented as robust, asynchronous background workers (`app/services/scheduler.py`). To handle external API limits, especially for a free tier, caching is aggressively implemented across all the satellite service handlers (`app/services/agromonitoring_service.py`) via an `async_ttl_cache` decorator. It also intelligently falls back to mock responses if the `AGROMONITORING_API_KEY` is not present, preventing any application crashes.

## How and What APIs are Working?
The backend communicates with the **Agromonitoring API (REST)**. The implemented satellite endpoints are:
1. **Polygon Registration (`/polygons`)**: Converts user-drawn PostGIS boundaries into GeoJSON and registers the polygon to obtain a unique `poly_id`.
2. **NDVI Satellite Imagery (`/ndvi/history`)**: Polls the last 30 days of Sentinel/Landsat imaging for the polygon and extracts the most recent mean NDVI (Normalized Difference Vegetation Index) value.
3. **Satellite Soil Data (`/soil`)**: Fetches current soil moisture and surface/depth temperatures directly from satellite mappings.
4. **Current & Forecasted Weather (`/weather` & `/weather/forecast`)**: Gives current weather and 7-day detailed forecasting based on the exact GPS centroid of the field.
5. **Additional/On-Demand Services**: Implementations exist for historical weather/soil (`/history`), Accumulative Temperature (Growing Degree Days), Accumulative Precipitation, and UV indexing (`/uvi`). These are also properly cached.

## Data Flow Pipeline
The entire pipeline runs entirely automatically in the background without user intervention:

### 1. Polygon Registration & Sync (Runs Every 1 Hour)
Function: `sync_satellite_data()` in `scheduler.py`
- Connects to the database and iterates through all stored agricultural `Field`s.
- Checks if the field has an `agromonitory_poly_id`. If not, it runs `ST_AsGeoJSON` on the PostGIS geometry and executes `create_polygon()`.
- Once registered, it immediately triggers `get_ndvi_for_field(poly_id)` which pulls the latest crop health index (NDVI).
- Real-time updates: `field.latest_ndvi` and `field.last_satellite_sync` are successfully persisted in the database.

### 2. Multi-Modal AI Synthesis (Runs Every 4 Hours)
Function: `ai_reasoning_loop()` & `run_ai_for_field()` in `scheduler.py` 
- Iterates over all fields again.
- Takes the freshly synced `latest_ndvi` value and computes a quick plant health trend (e.g., `< 0.25` is "critically low").
- Triggers `get_soil_data(poly_id)` via satellite to get ground moisture percentage and temperatures.
- Executes an `ST_Centroid` spatial query on the field's boundary to find its exact center GPS coordinates (`lat`, `lon`), which are then passed to `get_weather_forecast(lat, lon)`.
- **Merge Stage**: Gathers the last 24 hours of ESP32 IoT hardware sensor readings (if any exist) and merges them with the satellite data.
- **AI Brain**: This massive aggregated context chunk is sent to Gemini AI (`generate_field_recommendations`).
- The AI's intelligent outputs are subsequently deleted (old ones) and the new ones inserted into the `FieldRecommendation` SQL table for the frontend iOS App to display natively.

### 3. On-Demand Trigger 
Function: `POST /api/fields/{field_id}/recommendations/refresh/`
- If a user explicitly wants new insights inside the iOS app on the spot, this endpoint hits `trigger_recommendation_refresh()` which forces step 2 (Multi-Modal AI Synthesis) to execute bypassing the 4-hour chronological loop.
