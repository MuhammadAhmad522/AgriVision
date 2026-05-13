# AgriVision APIs and Services Summary

Last updated: 2026-04-15

## 1) Backend API Overview

Backend app entrypoint: AgriVision-Backend/app/main.py

- Framework: FastAPI
- Base URL (local default): http://localhost:8000
- Auth: Firebase Bearer token for protected routes via HTTP Authorization header
- Startup behavior:
  - Initializes Firebase Admin SDK
  - Ensures PostGIS and TimescaleDB extensions
  - Creates DB tables
  - Starts MQTT ingestion bridge
  - Starts Satellite sync worker (hourly)
  - Starts AI reasoning worker (every 4 hours)

### Health endpoints

1. `GET /`
- Purpose: Basic service status message.
- Auth: No
- Response: message text

2. `GET /health`
- Purpose: Health check and API version.
- Auth: No
- Response: status and version

### Fields API (`/api/fields`)

Source: AgriVision-Backend/app/api/fields.py

1. `POST /api/fields/`
- Purpose: Create a field polygon and optionally attach sensors.
- Auth: Yes
- Body:
  - name: string
  - coordinates: array of {longitude, latitude} (min 3)
  - area_ha, crop_type, plantation_date, expected_harvest_date
  - sensors: optional array of sensor configs
- Notes:
  - Converts coordinates to WKT polygon (SRID=4326)
  - If sensor exists by `device_id`, links it to field; otherwise creates it

2. `GET /api/fields/`
- Purpose: List current user fields.
- Auth: Yes

3. `GET /api/fields/{field_id}`
- Purpose: Get one field by UUID.
- Auth: Yes

4. `DELETE /api/fields/{field_id}`
- Purpose: Delete one field.
- Auth: Yes

### Sensors API (`/api/sensors`)

Source: AgriVision-Backend/app/api/sensors.py

1. `GET /api/sensors/verify/{device_id}`
- Purpose: Verify if sensor exists and has recent heartbeat.
- Auth: No (current implementation)
- Logic:
  - Returns verified if `last_seen` is within 60 minutes
  - Otherwise returns not verified with reason

### AI Recommendations API (`/api/fields/{field_id}/recommendations`)

Source: AgriVision-Backend/app/api/recommendations.py

1. `GET /api/fields/{field_id}/recommendations/?limit=10`
- Purpose: Fetch latest recommendations for a field.
- Auth: Yes
- Ownership check: enforced

2. `PUT /api/fields/{field_id}/recommendations/{recommendation_id}/feedback`
- Purpose: Save farmer feedback status for a recommendation.
- Auth: Yes
- Allowed status values: `pending`, `implemented`, `ignored`

3. `POST /api/fields/{field_id}/recommendations/refresh/`
- Purpose: Trigger immediate AI analysis for one field.
- Auth: Yes
- Response: 202 Accepted
- Note: Requires field to have `agromonitory_poly_id`

### AI Chat API (`/fields/{field_id}/chat`)

Source: AgriVision-Backend/app/api/chat.py

1. `GET /fields/{field_id}/chat`
- Purpose: Return full chat history for a field.
- Auth: No (current implementation)

2. `POST /fields/{field_id}/chat`
- Purpose: Send user message, generate contextual AI response, persist both.
- Auth: No (current implementation)
- Pipeline:
  - Save user message
  - Gather recent chat + recommendation memory
  - Call AI advisor service
  - Save model response

## 2) Backend Services Summary

### 2.1 Authentication service

Source: AgriVision-Backend/app/core/auth.py

- `get_current_user(...)`
- Verifies Firebase ID token, finds or auto-creates local user in Postgres
- Used by protected APIs

### 2.2 Agromonitoring integration service

Source: AgriVision-Backend/app/services/agromonitoring_service.py

Capabilities:
- Create polygon in Agromonitoring
- Fetch NDVI history (latest point)
- Fetch soil data (moisture and temperature)
- Fetch weather current + forecast
- Fetch imagery metadata and weather history helpers

Key behavior:
- Uses async HTTP (`httpx`)
- Includes async TTL cache helpers to reduce rate-limit pressure
- Returns mock/fallback data when API key is absent

### 2.3 AI advisor service

Source: AgriVision-Backend/app/services/ai_advisor_service.py

Capabilities:
- Build full context block from field, satellite, sensor, weather, and memory signals
- Generate structured recommendations via Gemini
- Handle chat with contextual agronomy assistant
- Includes deterministic rule-based fallback recommendation logic

Main public functions:
- `generate_field_recommendations(...)`
- `chat_with_advisor(...)`

### 2.4 MQTT ingestion service

Source: AgriVision-Backend/app/services/mqtt_service.py

Capabilities:
- Subscribes to `agrivision/sensors/+/readings`
- Auto-discovers new sensor devices by `device_id`
- Persists telemetry into `SensorReading`
- Updates sensor heartbeat (`last_seen`)

Main public function:
- `run_in_background()`

### 2.5 Scheduler/background orchestration service

Source: AgriVision-Backend/app/services/scheduler.py

Capabilities:
- Satellite sync loop (`sync_satellite_data`) every 1 hour
- AI reasoning loop (`ai_reasoning_loop`) every 4 hours
- On-demand AI run per field (`run_ai_for_field`)

Public starters:
- `start_satellite_sync_worker()`
- `start_ai_reasoning_worker()`

### 2.6 Serial-to-MQTT bridge script

Source: AgriVision-Backend/scripts/serial_to_mqtt_bridge.py

Purpose:
- Reads JSON telemetry from ESP32 over serial
- Publishes each reading to MQTT topic format:
  - `agrivision/sensors/{device_id}/readings`

## 3) iOS App Service Layer Summary

### 3.1 Networking constants

Source: AgriVision/Core/Networking/APIConstants.swift

- `baseURL`: `http://localhost:8000`
- Endpoint builders for fields, recommendations, feedback, chat, and sensor verification

### 3.2 Protocol abstractions

Sources:
- AgriVision/Data/Protocols/AgriDataService.swift
- AgriVision/Data/Protocols/AuthService.swift
- AgriVision/Data/Protocols/UserProfileService.swift
- AgriVision/Data/Protocols/PreferencesService.swift
- AgriVision/Data/Protocols/OnboardingStateService.swift

Responsibilities:
- `AgriDataService`: field CRUD, recommendations, chat, sensor verify, sensor readings
- `AuthService`: Firebase + Google auth lifecycle and ID token access
- `UserProfileService`: profile updates
- `PreferencesService`: persisted app preferences (saved email, active field)
- `OnboardingStateService`: onboarding completion flag

### 3.3 Concrete service/repository implementations

Sources:
- AgriVision/Data/Repositories/NetworkAgriDataRepository.swift
- AgriVision/Data/Repositories/FirebaseAuthService.swift
- AgriVision/Data/Repositories/FirebaseUserProfileService.swift
- AgriVision/Data/Repositories/UserDefaultsPreferencesService.swift
- AgriVision/Data/Repositories/UserDefaultsOnboardingStateService.swift

Responsibilities:
- `NetworkAgriDataRepository`: Authenticated HTTP client for backend APIs
- `FirebaseAuthService`: Sign in/out, sign up, Google link/sign-in, token retrieval
- `FirebaseUserProfileService`: Display name updates
- `UserDefaultsPreferencesService`: local persisted preferences
- `UserDefaultsOnboardingStateService`: local onboarding state

## 4) Current API/Client Contract Notes

1. The iOS repository expects `GET api/sensors/readings/` through `APIConstants.Endpoints.readings`, but there is no matching backend route in AgriVision-Backend/app/api/sensors.py.
2. Chat endpoints currently use `/fields/{field_id}/chat` (without `/api` prefix), and iOS constants match that path.
3. Some backend routes are authenticated (fields/recommendations), while sensor verify and chat are currently open in code.
