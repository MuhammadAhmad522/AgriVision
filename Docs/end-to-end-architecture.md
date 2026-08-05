# AgriVision — End-to-End Architecture

A full-stack precision agriculture platform connecting **ESP32 IoT sensors** → **MQTT broker** → **FastAPI backend** → **PostgreSQL/PostGIS** → **Gemini AI** → **iOS app**. Farmers monitor field conditions, satellite imagery, weather, soil data, and AI-generated agronomic advice in one place.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Project Structure](#2-project-structure)
3. [Backend — FastAPI (Python)](#3-backend--fastapi-python)
   - 3.1 Entry Point & Lifespan
   - 3.2 Configuration
   - 3.3 Database Models (17 tables)
   - 3.4 Pydantic Schemas
   - 3.5 API Routers (7 routers, ~35 endpoints)
   - 3.6 Services (5 services)
   - 3.7 Core Modules
   - 3.8 Background Workers
   - 3.9 Database Migrations (5 migrations)
4. [iOS App — SwiftUI](#4-ios-app--swiftui)
   - 4.1 Architecture: MVVM-C
   - 4.2 Navigation Flow
   - 4.3 All API Calls (20 endpoints)
   - 4.4 Key Models & ViewModels
   - 4.5 Dependencies
5. [ESP32 Firmware](#5-esp32-firmware)
   - 5.1 Dev Mode
   - 5.2 Prod Mode
   - 5.3 Sensor Readings
   - 5.4 MQTT Data Format
   - 5.5 Build Environments
6. [Infrastructure](#6-infrastructure)
   - 6.1 Docker Compose (6 services)
   - 6.2 Networks & Volumes
   - 6.3 Dockerfile
7. [Development Tools & Scripts](#7-development-tools--scripts)
8. [Testing](#8-testing)
9. [End-to-End Data Flows](#9-end-to-end-data-flows)

---

## 1. System Overview

```
┌──────────────┐    USB Serial     ┌────────────────────┐
│  ESP32 Sensor │ ────────────────→ │ serial_to_mqtt_    │
│  (DEV mode)   │                   │ bridge.py (dev)    │
└──────────────┘                   └────────┬───────────┘
                                           │ MQTT
                                           ▼
┌──────────────┐    WiFi + MQTT    ┌────────────────────┐
│  ESP32 Sensor │ ────────────────→ │   Mosquitto MQTT   │
│  (PROD mode)  │                   │   Broker (Docker)  │
└──────────────┘                   └────────┬───────────┘
                                           │ MQTT
                                           ▼
┌─────────────────────────────────────────────────────────┐
│                FastAPI Backend (Docker)                  │
│  ┌───────────┐  ┌──────────┐  ┌──────────────────────┐ │
│  │ MQTT      │  │ Scheduler│  │ API Routers          │ │
│  │ Consumer  │  │ Workers  │  │ (fields, sensors,     │ │
│  │ (async    │  │ (sync    │  │  chat, recommend,    │ │
│  │  queue)   │  │  loops)  │  │  satellite, session) │ │
│  └─────┬─────┘  └────┬─────┘  └──────────┬───────────┘ │
│        │             │                    │             │
│        ▼             ▼                    ▼             │
│  ┌────────────────────────────────────────────────┐     │
│  │         SQLAlchemy ORM + PostgreSQL             │     │
│  │  (PostGIS + TimescaleDB + 17 tables)            │     │
│  └────────────────────────────────────────────────┘     │
│        │                    │                    │       │
│        ▼                    ▼                    ▼       │
│  ┌──────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │AgroMonitor│    │  Gemini AI   │    │  Firebase     │  │
│  │  ing API  │    │  (Vertex AI) │    │  Auth         │  │
│  └──────────┘    └──────────────┘    └──────────────┘  │
└─────────────────────────────────────────────────────────┘
           │ HTTP REST (JSON)
           ▼
┌─────────────────────────────────────────┐
│         iOS App (SwiftUI + MVVM-C)       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │ Dashboard│ │ Fields   │ │ AI Chat  │ │
│  │  View    │ │  View    │ │  View    │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ │
│       │            │            │       │
│  ┌────┴────────────┴────────────┴────┐  │
│  │     NetworkAgriDataRepository     │  │
│  │     + APIClient (URLSession)     │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

---

## 2. Project Structure

```
AgriVision/                          # iOS App (SwiftUI, ~9,875 lines)
├── AgriVision.xcodeproj/
├── AgriVision-Info.plist
├── GoogleService-Info.plist
├── AppDelegate.swift / SceneDelegate.swift
├── Core/                # Config, Navigation, Networking, UI, Utils
├── Data/                # Protocols, Models, Repositories
├── Features/            # Splash, Onboarding, Auth, Dashboard, Settings,
│                        # AIChat, FieldSelection, SensorIntegration
└── Assets.xcassets/

AgriVision-Backend/                  # Python Backend (~3,730 lines)
├── app/
│   ├── main.py                      # FastAPI app, lifespan, middleware
│   ├── database.py                  # SQLAlchemy engine + session
│   ├── api/                         # 7 routers
│   │   ├── session.py               #   Session bootstrap
│   │   ├── fields.py                #   Field CRUD, dashboard
│   │   ├── sensors.py               #   Sensor readings, pair, verify
│   │   ├── chat.py                  #   AI chat with images
│   │   ├── recommendations.py        #   AI recommendations
│   │   └── satellite.py             #   Satellite imagery
│   ├── core/
│   │   ├── config.py                #   Settings (35+ env vars)
│   │   ├── auth.py                  #   Firebase token verification
│   │   ├── errors.py                #   APIError + error_payload
│   │   └── rate_limit.py            #   InMemoryRateLimiter
│   ├── models/
│   │   └── db_models.py             #   17 SQLAlchemy models
│   ├── schemas/
│   │   └── pydantic_schemas.py      #   20+ Pydantic models
│   └── services/
│       ├── agromonitoring_service.py #   AgroMonitoring REST client
│       ├── ai_advisor_service.py     #   Gemini AI integration
│       ├── chat_media_service.py     #   Image upload/storage
│       ├── mqtt_service.py           #   MQTT ingestion (async)
│       └── scheduler.py              #   Background workers
├── alembic/                         # 5 database migrations
├── scripts/
│   └── serial_to_mqtt_bridge.py      # USB → MQTT bridge (dev)
├── tests/                           # 21 test files, 150 tests
├── docker-compose.yml               # 6 services
├── Dockerfile
└── requirements.txt

esp/                                 # ESP32 Firmware (C++, ~210 lines)
├── src/
│   ├── config.h                     # WiFi/MQTT/device credentials
│   └── main.cpp                     # Sensor read + publish
├── platformio.ini                   # 2 build environments
└── boards/                          # Custom S3 devkit board definition
```

---

## 3. Backend — FastAPI (Python)

### 3.1 Entry Point & Lifespan

**File:** `app/main.py` (158 lines)

The `FastAPI` application starts with an `asynccontextmanager` lifespan hook that runs on startup:

1. **`_initialize_firebase()`** — Initializes Firebase Admin SDK for auth token verification. Gracefully continues if credentials are missing (auth fallback to fail-closed mode).
2. **`_prepare_database()`** — Runs Alembic migrations automatically. Creates PostGIS extension, TimescaleDB extension, and `sensor_readings` hypertable if needed. Has 5 retries with 3s delay.
3. **Start background workers:**
   - MQTT async consumer (`await start_background_tasks()`)
   - Satellite data sync loop (`external_data_loop`)
   - AI reasoning loop (`ai_reasoning_loop`)
   - Sensor aggregation loop (`_aggregation_loop`)
4. On shutdown, cancels all background tasks.

**Middleware stack:**
- `CORSMiddleware` — configurable origins
- `request_context` — adds `X-Request-ID`, validates `Content-Length`, adds security headers (`X-Content-Type-Options`, `X-Frame-Options`)
- Exception handlers for `APIError`, `RequestValidationError`, `HTTPException`, and unhandled exceptions

**Health endpoints:**
| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/` | Root health check |
| `GET` | `/health` | Detailed health (DB connection, Firebase status, environment) |

### 3.2 Configuration

**File:** `app/core/config.py` (73 lines)

**Class:** `Settings(BaseSettings)` — loaded from environment variables via `pydantic_settings`.

| Category | Settings | Default | Description |
|----------|----------|---------|-------------|
| **Project** | `PROJECT_NAME`, `ENVIRONMENT` | "AgriVision API", "development" | App metadata |
| **Database** | `DATABASE_URL` | `postgresql://admin:password@db:5432/agrivision` | PostgreSQL connection |
| | `ENABLE_TIMESCALEDB` | `False` | TimescaleDB hypertable |
| **Redis** | `REDIS_URL` | `redis://redis:6379/0` | Reserved for future use |
| **Firebase** | `FIREBASE_SERVICE_ACCOUNT_PATH` | `/app/firebase-credentials.json` | Auth credentials |
| | `FIREBASE_CLOCK_SKEW_SECONDS` | 5 | Token tolerance (0-60) |
| | `FIREBASE_CHECK_REVOKED` | `False` | Online revocation check |
| | `FIREBASE_VERIFY_TIMEOUT_SECONDS` | 8.0 | Auth timeout (0-30) |
| **MQTT** | `MQTT_BROKER`, `MQTT_PORT` | "mqtt", 1883 | Broker connection |
| | `MQTT_USERNAME`, `MQTT_PASSWORD` | None | Optional auth |
| **AgroMonitoring** | `AGROMONITORING_API_KEY` | "" | API key for satellite/weather |
| | `AGRO_FREE_MODE` | `True` | Skip paid-only endpoints |
| | `AGRO_SATELLITE_INTERVAL_HOURS` | 6 | Global satellite sync interval |
| | `AGRO_SOIL_INTERVAL_HOURS` | 6 | Global soil sync interval |
| | `AGRO_WEATHER_INTERVAL_HOURS` | 6 | Global weather sync interval |
| | `AGRO_UVI_INTERVAL_HOURS` | 6 | Global UV sync interval |
| | `AGRO_INITIAL_SYNC_TIMEOUT_SECONDS` | 15 | Initial sync timeout |
| | `AGRO_WORKER_SCAN_SECONDS` | 300 (5 min) | Background loop sleep |
| | `AGRO_MAX_CONCURRENCY` | 2 | Max concurrent API calls |
| | `AGRO_MEDIA_ROOT` | `./media/agro` | Satellite image storage |
| **AI (Gemini)** | `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION` | "", "global" | Vertex AI project |
| | `GOOGLE_GENAI_USE_VERTEXAI` | `True` | Use Vertex AI vs API key |
| | `GOOGLE_AI_MODEL` | "gemini-3.5-flash" | Model name |
| | `AI_PROMPT_VERSION` | "agrivision-punjab-v2" | Prompt version tag |
| | `AI_POLICY_VERSION` | "guarded-advisory-v1" | Safety policy version |
| | `AI_PROVIDER_TIMEOUT_SECONDS` | 45.0 | AI call timeout (0-120) |
| **Chat** | `CHAT_MEDIA_ROOT` | `./media/chat` | Image attachment storage |
| | `CHAT_GCS_BUCKET` | "" | Cloud Storage bucket (empty = local) |
| | `CHAT_MAX_IMAGES` | 3 | Max images per message |
| | `CHAT_MAX_IMAGE_BYTES` | 10 MB | Max image file size |
| | `CHAT_MAX_PIXELS` | 24 MP | Max image resolution |
| | `CHAT_MAX_DIMENSION` | 2048 | Max dimension after resize |
| | `CHAT_REQUEST_MAX_BYTES` | 32 MB | Max upload size |
| **Limits** | `ACTIVE_FIELD_LIMIT` | 5 | Max fields per user |
| | `MAX_REQUEST_BODY_BYTES` | 1 MB | Max non-chat request body |
| | `ALLOWED_ORIGINS` | "" | CORS origins (comma-separated) |

### 3.3 Database Models (17 tables)

**File:** `app/models/db_models.py` (326 lines)

#### `users`
Core user table, linked to Firebase Auth via `firebase_uid`.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `firebase_uid` | String(128) | UNIQUE, INDEX |
| `email` | String(320) | UNIQUE, INDEX |
| `created_at` | DateTime | |

#### `fields`
Agricultural field with PostGIS polygon boundary.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `owner_id` | UUID → users.id | FK, INDEX |
| `name` | String(100) | |
| `crop_type` | String(80) | |
| `plantation_date` | DateTime(tz) | |
| `expected_harvest_date` | DateTime(tz) | |
| `boundary` | Geometry("POLYGON", 4326) | PostGIS |
| `area_ha` | Float | Computed from boundary |
| `status` | String(20) | "active", "deleting" |
| `agromonitory_poly_id` | String(64) | AgroMonitoring polygon ID |
| `agro_status` | String(24) | "pending", "available", "unavailable", "unsupported" |
| `agro_error` | String(500) | |
| `agro_retryable` | Boolean | |
| `latest_ndvi` | Float | Latest NDVI value |
| `last_satellite_sync` | DateTime(tz) | |
| `interval_overrides` | JSONB | Per-field timing overrides, default `{}` |
| **Relations:** | owner, sensors, recommendations, observations, satellite_scenes, chat_attachments | |

#### `sensors`
IoT sensor devices paired to fields.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `owner_id` | UUID → users.id | INDEX |
| `field_id` | UUID → fields.id | ON DELETE SET NULL |
| `device_id` | String(100) | UNIQUE |
| `name` | String(100) | Optional display name |
| `sensor_type` | String(50) | Default: "multi_sensor" |
| `battery_level` | Float | |
| `last_seen` | DateTime(tz) | Last MQTT message |

#### `sensor_readings`
Timeseries data from IoT sensors. Composite PK designed for TimescaleDB hypertable.

| Column | Type | Notes |
|--------|------|-------|
| `time` | DateTime(tz) | PK (composite) |
| `sensor_id` | UUID → sensors.id | PK (composite), ON DELETE CASCADE |
| `temperature` | Float | °C |
| `moisture` | Float | % |
| `humidity` | Float | % |
| `ph` | Float | |
| `ec` | Float | Electrical conductivity |
| `npk_n, npk_p, npk_k` | Float | Nitrogen, Phosphorus, Potassium |

#### `sensor_readings_hourly`
Pre-aggregated hourly summaries for efficient charting.

| Column | Type | Notes |
|--------|------|-------|
| `bucket` | DateTime(tz) | PK (composite), date_trunc('hour') |
| `sensor_id` | UUID → sensors.id | PK (composite) |
| `temperature_avg/min/max` | Float | |
| `moisture_avg/min/max` | Float | |
| `humidity_avg/min/max` | Float | |
| `ph_avg/min/max` | Float | |
| `ec_avg/min/max` | Float | |
| `npk_n_avg/min/max` | Float | |
| `npk_p_avg/min/max` | Float | |
| `npk_k_avg/min/max` | Float | |
| `reading_count` | Integer | Number of raw readings in bucket |

#### `field_observations`
Normalized provider data (satellite, soil, weather, UVI, accumulations).

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `field_id` | UUID → fields.id | FK, INDEX, CASCADE |
| `source` | String(40) | "agromonitoring", "local_derived" |
| `metric` | String(60) | "soil_current", "weather_forecast", "uvi_current", "ndvi", etc. |
| `value` | Float | Numeric value |
| `unit` | String(30) | "m3/m3", "index", "°C" |
| `payload` | JSONB | Full API response |
| `observed_at` | DateTime(tz) | When data was observed |
| `fetched_at` | DateTime(tz) | When data was fetched |
| `expires_at` | DateTime(tz) | When data is considered stale |
| **Constraint:** | UNIQUE(field_id, source, metric, observed_at) | |

#### `satellite_scenes`
Satellite imagery metadata for NDVI/truecolor.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `field_id` | UUID → fields.id | FK, CASCADE |
| `provider_scene_id` | String(160) | |
| `provider` | String(40) | Default: "agromonitoring" |
| `source_type` | String(20) | "s2" (Sentinel-2) |
| `acquired_at` | DateTime(tz) | Scene acquisition time |
| `cloud_percent` | Float | |
| `coverage_percent` | Float | |
| `statistics` | JSONB | NDVI, EVI, EVI2 stats |
| `ndvi_image_path` | String(500) | Local file path |
| `truecolor_image_path` | String(500) | Local file path |
| **Constraint:** | UNIQUE(field_id, provider_scene_id) | |

#### `ai_analysis_runs`
Tracks each AI analysis execution with context fingerprint for dedup.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `field_id` | UUID → fields.id | FK, CASCADE |
| `provider` | String(40) | |
| `status` | String(20) | "running", "completed", "failed" |
| `context_snapshot` | JSONB | Full context at analysis time |
| `context_fingerprint` | String(64) | SHA-256 of context for dedup |
| `model_name` | String(100) | |
| `prompt_version` | String(40) | |
| `policy_version` | String(40) | |
| `data_quality` | String(20) | "good", "limited", "insufficient" |
| `evidence` | JSONB | Source observations used |
| `error` | String(500) | Error message on failure |
| `started_at` | DateTime(tz) | |
| `completed_at` | DateTime(tz) | |

#### `field_recommendations`
AI-generated agronomic recommendations with feedback loop.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `field_id` | UUID → fields.id | FK, CASCADE |
| `analysis_run_id` | UUID → ai_analysis_runs.id | FK, SET NULL |
| `category` | String(50) | 7 categories (see below) |
| `priority` | String(20) | "low", "medium", "high" |
| `advice` | Text | The recommendation text |
| `rationale` | Text | Why recommended |
| `confidence` | Float | 0.0–1.0 |
| `confidence_reason` | String(500) | |
| `evidence` | JSONB | Source URLs |
| `safety_level` | String(20) | "guarded", "verified", "expert_only" |
| `requires_expert_confirmation` | Boolean | |
| `status` | String(20) | "pending", "implemented", "ignored", "superseded" |
| `ndvi_at_generation` | Float | NDVI when generated |
| `feedback_at` | DateTime(tz) | |
| `expires_at` | DateTime(tz) | 7 days |
| `outcome` | String(20) | "useful", "ineffective", "harmful" |
| `outcome_notes` | Text | |
| **Categories:** | Irrigation, Plant Health, Weather Alert, Fertilizer Window, Harvest Timing, Pest Risk, Field Monitoring | |

#### `ai_chat_threads`
One thread per field for AI chat history.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `field_id` | UUID → fields.id | UNIQUE |
| `rolling_summary` | Text | Condensed conversation history |
| `summarized_through` | DateTime(tz) | |
| `created_at`, `updated_at` | DateTime(tz) | |

#### `ai_chat_messages`
Individual chat messages (user + model turns).

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `field_id` | UUID → fields.id | FK, CASCADE |
| `thread_id` | UUID → ai_chat_threads.id | FK, CASCADE |
| `reply_to_message_id` | UUID → ai_chat_messages.id | FK, CASCADE |
| `role` | String(20) | "user", "model" |
| `content` | Text | Message body |
| `idempotency_key` | String(100) | For dedup |
| `status` | String(20) | "completed" |
| **Constraint:** | UNIQUE(field_id, idempotency_key) | |

#### `chat_attachments`
Image attachments for chat messages.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `field_id` | UUID → fields.id | FK, CASCADE |
| `message_id` | UUID → ai_chat_messages.id | FK, CASCADE |
| `storage_key` | String(500) | UNIQUE |
| `mime_type`, `byte_size`, `width`, `height` | | |
| `sha256` | String(64) | Content hash |

#### `provider_capabilities`
Tracks which data sources work for each field (handles free-tier limits).

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `provider` | String(40) | |
| `capability` | String(80) | "uvi_forecast", "accumulated_temperature", "sync:weather_forecast", etc. |
| `field_id` | UUID → fields.id | FK, CASCADE |
| `status` | String(20) | "supported", "unsupported", "unavailable" |
| `status_code` | Integer | HTTP status |
| `checked_at` | DateTime(tz) | |
| `detail` | String(300) | |
| **Constraint:** | UNIQUE(provider, capability, field_id) | |

#### `provider_request_logs`
Telemetry for all AgroMonitoring API calls.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `provider` | String(40) | |
| `endpoint` | String(100) | |
| `field_id` | UUID → fields.id | FK, CASCADE |
| `outcome` | String(20) | "success", "failure", "denied", "cache_hit", "rejected" |
| `status_code` | Integer | |
| `cache_hit` | Boolean | |
| `duration_ms` | Integer | |

#### `provider_cache`
Response cache for AgroMonitoring (avoids redundant API calls).

| Column | Type | Notes |
|--------|------|-------|
| `cache_key` | String(64) | PK (SHA-256 of request) |
| `provider` | String(40) | |
| `endpoint` | String(100) | |
| `field_id` | UUID → fields.id | FK, CASCADE |
| `response_payload` | JSONB | Cached response |
| `expires_at` | DateTime(tz) | TTL-based expiry |

#### `field_deletion_jobs`
Async cleanup jobs when fields are deleted.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `field_id` | UUID | |
| `provider_polygon_id` | String(64) | AgroMonitoring polygon to delete |
| `media_paths` | JSONB | Files to clean up |
| `status` | String(20) | "pending", "running", "completed" |
| `attempts` | Integer | Retry counter |
| `last_error` | String(500) | |
| `next_attempt_at` | DateTime(tz) | Exponential backoff |

#### `agronomy_knowledge_documents`
Reference documents for AI knowledge retrieval (future Vertex Search integration).

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `external_id` | String(160) | UNIQUE |
| `title`, `source_url` | | |
| `crop`, `region` | | INDEX |
| `approved` | Boolean | Manual approval required |

### 3.4 Pydantic Schemas

**File:** `app/schemas/pydantic_schemas.py` (259 lines)

| Model | Type | Used By | Key Fields |
|-------|------|---------|------------|
| `FieldIntervalOverrides` | Request | FieldUpdate | `weather_hours`, `soil_hours`, `uvi_hours`, `satellite_hours`, `ai_hours` (1-720), `retention_days` (1-365) |
| `FieldCreate` | Request | POST /api/fields | `name`, `coordinates` (3-500 points), `crop_type`, `dates` |
| `FieldWithSensorsCreate` | Request | POST /api/fields | Extends FieldCreate with `sensors` list |
| `FieldUpdate` | Request | PATCH /api/fields | `name`, `crop_type`, `expected_harvest_date`, `interval_overrides` |
| `FieldResponse` | Response | Field endpoints | Full field data + `interval_overrides` (dict) |
| `SensorCreate` | Request | Field creation | `device_id`, `sensor_type` |
| `SensorPairRequest` | Request | POST /api/sensors/pair | `device_id` |
| `SensorPairResponse` | Response | Pair endpoint | `is_paired`, `message`, `sensor` |
| `SensorReadingDB` | Response | Get readings | All sensor metric fields |
| `SensorReadingHourlyDB` | Response | Aggregated readings | Bucket timestamp + avg/min/max per metric |
| `RecommendationResponse` | Response | Recommendation endpoints | Full recommendation with category, priority, advice, evidence |
| `RecommendationFeedback` | Request | POST feedback | `status` (pending/implemented/ignored) |
| `RecommendationOutcome` | Request | POST outcome | `outcome` (useful/ineffective/harmful), `notes` |
| `ChatMessageRequest` | Request | POST chat | `message` (1-2000 chars) |
| `ChatMessageResponse` | Response | Chat endpoints | `role`, `content`, `attachments` |
| `ChatTurnResponse` | Response | POST chat | `user_message` + `assistant_message` |
| `SessionBootstrapResponse` | Response | POST bootstrap | `user`, `fields`, `active_field_limit`, `active_field_count` |
| `ErrorBody` / `ErrorEnvelope` | Response | All errors | `code`, `message`, `details`, `retryable`, `request_id` |

### 3.5 API Routers (7 routers, ~35 endpoints)

#### Session Router (`/api/session`)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/session/bootstrap` | Yes | Returns user info, all active fields, field limit info |

#### Fields Router (`/api/fields`)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/fields` | Yes | List user's fields (optional `include_archived`) |
| POST | `/api/fields` | Yes | Create field with WKT validation, area check (1-3000 ha), active limit (5 max), sensor assignment, initial AgroMonitoring sync, AI trigger |
| GET | `/api/fields/{id}` | Yes | Get single field |
| PATCH | `/api/fields/{id}` | Yes | Update name, crop_type, harvest_date, interval_overrides |
| DELETE | `/api/fields/{id}` | Yes | Soft-delete → creates FieldDeletionJob for async cleanup |
| POST | `/api/fields/{id}/sensors` | Yes | Assign pre-paired sensor to field |
| GET | `/api/fields/{id}/sensors` | Yes | List sensors on field |
| POST | `/api/fields/{id}/data-refresh` | Yes | Trigger full provider data refresh (rate-limited) |
| GET | `/api/fields/{id}/dashboard` | Yes | Full dashboard: satellite, soil, weather, UVI, sensors, advisor, recommendations |
| POST | `/api/fields/{id}/harvest` | Yes | **Deprecated** — returns 410 |
| GET | `/api/fields/{id}/weather-soil` | Yes | Legacy compat endpoint |

**Field creation flow (detailed):**
1. Rate limit check (20 creates/hour)
2. Advisory lock per tenant (`pg_advisory_xact_lock`)
3. Active field count check (max 5)
4. WKT polygon validation (`ST_IsValid`)
5. Area computation (`ST_Area` → geography → hectares)
6. Range check (1–3000 ha)
7. Create field record + assign sensors
8. Start initial AgroMonitoring sync (with 15s timeout)
9. Queue AI analysis in background
10. Return FieldResponse

#### Sensors Router (`/api/sensors`)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/fields/{id}/sensor-readings` | Yes | Get readings with `granularity` (raw/hourly/daily), `hours` (1-720), `limit` |
| GET | `/api/sensors/verify/{device_id}` | Yes | Check if sensor is online (last_seen within 60 min) and claimable |
| POST | `/api/sensors/pair` | Yes | Claim an unowned, online sensor |

#### Chat Router (`/api/fields/{id}/chat`)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `` | Yes | Get paginated chat history with `before` cursor |
| GET | `/attachments/{id}` | Yes | Serve attachment image with correct MIME type |
| POST | `` | Yes | Send message (text + up to 3 images), idempotent via `Idempotency-Key` header |

**Chat flow (detailed):**
1. Validate `idempotency_key` format (8-100 chars, alphanumeric)
2. Advisory lock for idempotency (`pg_advisory_xact_lock`)
3. Check for existing completed turn by idempotency key
4. Input validation: clean text (reject control chars), max 2000 chars
5. Rate limit check (20 chats/hour)
6. Sanitize images (decode, strip EXIF, re-encode as JPEG, resize to max 2048px)
7. Get/create chat thread
8. Load history (last 20 messages), active recommendations (10), recent observations (30)
9. Build context + call Gemini AI
10. On success: persist user message, store images, persist assistant message, update rolling summary
11. On failure: rollback DB, delete stored images, raise error

#### Recommendations Router (`/api/recommendations`)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/fields/{id}/recommendations` | Yes | List (excludes superseded, sorted by created_at desc) |
| POST | `/api/fields/{id}/recommendations` | Yes | Trigger AI refresh (rate-limited) |
| POST | `/api/recommendations/{id}/feedback` | Yes | Set status (pending/implemented/ignored) |
| POST | `/api/recommendations/{id}/outcome` | Yes | Record outcome for implemented recs only |

#### Satellite Router (`/api/fields/{id}/satellite`)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/latest` | Yes | Latest scene metadata (acquired_at, cloud%, coverage%, statistics, image URLs) |
| GET | `/latest/ndvi` | Yes | Serve NDVI PNG image file |
| GET | `/latest/truecolor` | Yes | Serve truecolor PNG image file |

### 3.6 Services

#### `agromonitoring_service.py` (386 lines) — AgroMonitoring REST Client

**Architecture:** HTTP client with circuit breaker, retry, caching, singleflight dedup.

**State:**
- `_semaphore` — AsyncIO Semaphore (limits concurrent API calls, default 2)
- `_inflight` — Singleflight dedup map (key → asyncio.Task)
- `_circuit_open_until` — Circuit breaker (opens after 5 consecutive failures, closes after 300s)
- `_failure_count` — Consecutive failure counter

**Core function: `_request(method, endpoint, ...)`:**
1. Check circuit breaker → raise if open
2. Build URL with API key
3. Generate request fingerprint (SHA-256 of method+endpoint+params+body)
4. Check cache (GET, non-binary, TTL > 0) → return cached if fresh
5. Acquire semaphore
6. Retry loop (3 attempts):
   - Send HTTP request (20s timeout)
   - 401/402/403 → `AgroEntitlementError` (non-retryable, not cached)
   - 429/5xx → retry with exponential backoff (up to 30s for Retry-After)
   - 400-499 (non-429) → `AgroAPIError` (non-retryable)
   - Success → reset failure count, log telemetry, cache (GET), return
   - Network error → increment failure count, open circuit at 5 failures
7. All retries exhausted → raise `AgroAPIError`
8. Singleflight: concurrent calls with same fingerprint share one in-flight task

**All endpoints proxied:**
| Function | AgroMonitoring API |
|----------|-------------------|
| `create_polygon(name, geojson)` | POST `/polygons` (400 fallback → GET `/polygons` search) |
| `delete_polygon(polygon_id)` | DELETE `/polygons/{id}` |
| `search_latest_scene(polygon_id)` | GET `/image/search` (14-day window, Sentinel-2 filter) |
| `get_index_statistics(scene, index)` | GET scene stats URL (NDVI, EVI, EVI2) |
| `cache_scene_image(scene, index)` | Download image → save to `media/agro/{field_id}/` |
| `get_soil_data(polygon_id)` | GET `/soil` (Kelvin→Celsius conversion) |
| `get_weather_forecast(lat, lon)` | GET `/weather` + GET `/weather/forecast` (concurrent) |
| `get_current_uvi(polygon_id)` | GET `/uvi` |
| `get_forecast_uvi(polygon_id)` | GET `/uvi/forecast` |
| `get_accumulated_temperature(...)` | GET `/weather/history/accumulated_temperature` |
| `get_accumulated_precipitation(...)` | GET `/weather/history/accumulated_precipitation` |

#### `ai_advisor_service.py` (418 lines) — Gemini AI Integration

**Architecture:** Abstract provider pattern with safety policy layer.

**Provider hierarchy:**
```
AIProvider (ABC)
├── UnavailableAIProvider      — Fallback when AI is not configured
└── GeminiAIProvider           — Google Gemini (Vertex AI or API key)
    ├── Vertex AI: google-genai SDK with ADC
    └── API key: google-generativeai SDK (GOOGLE_API_KEY)
```

**Key functions:**
| Function | Purpose |
|----------|---------|
| `_approved_url(value)` | Checks URL against approved prefixes (Punjab gov, PARC, FAO, CIMMYT, IRRI) |
| `_canonical_category(value)` | Normalizes to 1 of 7 categories |
| `_recommendation_payload(response)` | Extracts structured JSON from Gemini response (handles code fences, raw JSON) |
| `_apply_safety_policy(item, approved_evidence)` | Filters URLs, blocks unverified chemical/spray/treatment advice, clamps confidence 0-1, sets safety level |
| `_guard_chat_response(text, ...)` | Guards chat responses: detects treatment advice without approved sources, adds disclaimer prefix |
| `get_ai_provider()` | Singleton factory (returns UnavailableAIProvider if no config, GeminiAIProvider otherwise) |

**Safety rules:**
- Chemical/pesticide advice requires at least one approved URL in evidence
- "spray", "pesticide", "insecticide", "fungicide", "herbicide" in chat text trigger guarding
- Confidence clamped to 0.0–1.0, invalid strings default to 0.4
- Priority defaults to "medium" for unknown values
- 7 canonical categories only (everything else maps to "Field Monitoring")

**AI Context includes:**
- Field info (name, area, crop, days since planting, region)
- Latest NDVI value
- Fresh observations (soil, weather, UVI — ordered by recency, limit 100)
- Sensor data summary (24h window, avg/min/max/latest per metric)
- Data quality assessment (good/limited/insufficient)
- Rolling chat summary

#### `chat_media_service.py` (165 lines) — Image Storage

**Architecture:** Abstract storage with local filesystem or GCS.

**Functions:**
| Function | Purpose |
|----------|---------|
| `sanitize_upload(upload)` | Validate MIME (JPEG/PNG/HEIC/WebP) → decode → strip EXIF → re-encode as JPEG → resize to max 2048px → compute SHA-256 |
| `get_chat_media_storage()` | Singleton: returns `GCSPrivateMediaStorage` if `CHAT_GCS_BUCKET` set, else `LocalPrivateMediaStorage` |

**Storage classes:**
| Class | Storage | Features |
|-------|---------|----------|
| `LocalPrivateMediaStorage` | Local filesystem under `CHAT_MEDIA_ROOT` | Path traversal protection (resolve + check prefix) |
| `GCSPrivateMediaStorage` | Google Cloud Storage | Bucket-based, similar interface |

#### `mqtt_service.py` (180 lines) — MQTT IoT Ingestion

**Architecture:** Thread-based MQTT listener → async queue → batched DB writer.

```
MQTT Network Thread (blocking)
    │ on_message() called for each message
    │ validates topic + payload format
    │ rate-limits per device (120 msg/60s)
    ▼
loop.call_soon_threadsafe(queue.put_nowait(item))
    │
    ▼
Async Queue (asyncio.Queue)
    │
    ▼
_db_writer_loop() (async consumer, runs in event loop)
    │ dequeues items in batches of up to 50
    │ calls asyncio.to_thread(_write_batch)
    │ drains remaining on CancelledError
    ▼
_write_batch(items) (in thread pool)
    │ Single transaction per batch
    │ Auto-discovers new sensors
    │ Creates SensorReading + updates last_seen
    ▼
PostgreSQL
```

**Message validation (on_message):**
1. Extract device_id from topic (`agrivision/sensors/{device_id}/readings`)
2. Parse JSON payload (max 16 KB)
3. Validate supported fields (temperature, moisture, humidity, ph, ec, npk_n, npk_p, npk_k)
4. Check for unsupported fields (reject if extra fields present)
5. Check value ranges (temperature: -50–100, moisture: 0–100, humidity: 0–100, ph: 0–14, ec: 0–10000, npk: 0–10000)
6. Rate limit per device (120 messages / 60 seconds)
7. Enqueue valid reading

#### `scheduler.py` (817 lines) — Background Workers

**Architecture:** 4 independent async loops + stateless sync functions.

**Background loops:**
| Loop | Sleep | Purpose |
|------|-------|---------|
| `external_data_loop()` | 300s (5 min) | Syncs all AgroMonitoring data sources for all active fields |
| `ai_reasoning_loop()` | 300s (5 min) | Runs AI analysis for all active fields |
| `_aggregation_loop()` | 3600s (1 hour) | Aggregates sensor readings hourly; purges raw at 3am |

**Sync functions (all support `force` parameter):**
| Function | Sources | Override Key |
|----------|---------|-------------|
| `_sync_satellite()` | Satellite search, NDVI/EVI/EVI2 stats, scene images | `satellite_hours` |
| `_sync_soil()` | Soil moisture, surface/depth temperature | `soil_hours` |
| `_sync_weather()` | Current weather + 5-day forecast | `weather_hours` |
| `_sync_uvi()` | Current UV index + forecast (if not free mode) | `uvi_hours` |
| `_sync_accumulations()` | Accumulated temperature/precipitation (or derive from cached weather) | `weather_hours` |

**AI analysis (`run_ai_for_field()`):**
1. Acquire advisory lock
2. Mark stale running runs as failed (exceeded 2× timeout)
3. Build context: observations (100), sensor readings (24h), sensor summary
4. Compute context fingerprint (SHA-256)
5. Check for duplicate (same fingerprint, model, prompt, policy) → skip
6. Create `AIAnalysisRun` with status "running"
7. Commit immediately (so dashboard sees the running state)
8. Call Gemini AI → parse recommendations → apply safety policy
9. Supersede old pending recommendations for same category
10. Mark run as "completed" or "failed"

**Field deletion (`process_field_deletion_job()`):**
1. Lock job row (`SELECT ... FOR UPDATE`)
2. Delete AgroMonitoring polygon (if provider_polygon_id set)
3. Remove satellite media directory
4. Remove chat media files
5. Mark job as "completed"
6. On failure: exponential backoff (2^attempts min, max 360 min), retry

**Sensor aggregation:**
- `_aggregate_sensor_readings()`: SQL `INSERT INTO sensor_readings_hourly ... SELECT date_trunc('hour', time) ... ON CONFLICT DO NOTHING`
- `_purge_raw_readings()`: SQL `DELETE FROM sensor_readings USING sensors, fields WHERE sr.time < NOW() - COALESCE(interval_overrides->>'retention_days', '14 days')`

**Per-field interval overrides:**
```python
def _override(field: Field, key: str) -> int | None:
    overrides = field.interval_overrides
    if overrides and isinstance(overrides, dict):
        return overrides.get(key)
    return None
```
Used in every sync function to replace global defaults.

### 3.7 Core Modules

#### `auth.py` — Firebase Authentication
- Extracts Bearer token from `Authorization` header via `HTTPBearer`
- Verifies with Firebase Admin SDK (`verify_id_token`)
- Looks up or creates `User` record by `firebase_uid`
- Updates email if changed
- 401 on invalid/expired tokens, 503 on Firebase unavailability

#### `errors.py` — Error Handling
- `APIError(status_code, code, message, details, retryable, headers)` — custom exception
- `error_payload(error, request_id)` — standard error JSON format

#### `rate_limit.py` — Rate Limiting
- `InMemoryRateLimiter` — per-key sliding window using `deque` timestamps
- `check(key, limit, window_seconds)` — raises `APIError(429)` if exceeded
- Used for: field creation (20/hr), chat (20/hr), AI refresh (4/hr), data refresh (4/hr)

### 3.8 Database Migrations (5 Alembic migrations)

| Migration | Revises | Description |
|-----------|---------|-------------|
| `0001_multitenant_multifield.py` | — (base) | Initial schema: creates all tables, adds columns to existing `fields`, `sensors`, `field_recommendations`, creates `field_observations`, `satellite_scenes`, `ai_analysis_runs`, `ai_chat_threads`, `provider_capabilities`, `provider_request_logs`, `provider_cache` |
| `0002_status_delete_multimodal_ai.py` | 0001 | Adds AI evidence fields, recommendation outcomes, chat idempotency, `chat_attachments`, `field_deletion_jobs`, `agronomy_knowledge_documents`, seeds 3 knowledge docs |
| `0003_reconcile_multimodal_schema.py` | 0002 | Adds missing `reply_to_message_id` FK to `ai_chat_messages` |
| `0004_sensor_aggregation.py` | 0003 | Creates `sensor_readings_hourly` with composite PK (bucket, sensor_id), all aggregation columns |
| `0005_field_interval_overrides.py` | 0004 | Adds `interval_overrides` JSONB column to `fields` with default `'{}'` |

---

## 4. iOS App — SwiftUI

### 4.1 Architecture: MVVM-C

- **Models**: Pure Swift structs in `Data/Models/`
- **Views**: "Dumb" SwiftUI `View` structs — only render state, forward actions
- **ViewModels**: `ObservableObject` classes with `@Published` properties — all business logic, validation, service calls
- **Coordinators**: UIKit navigation controllers — manage screen transitions, ViewModels communicate via callbacks

**Dependency injection** happens in `SceneDelegate` (composition root):
- Production: `NetworkAgriDataRepository`, `FirebaseAuthService`, `FirebaseUserProfileService`, `UserDefaultsOnboardingStateService`, `UserDefaultsPreferencesService`
- Mocks available: `MockAgriDataRepository`, `MockAuthService`, `MockUserProfileService`, `MockPreferencesService`

**Key architectural principles:**
- Dependency Inversion — all services depend on protocols
- Single Responsibility — ViewModels handle logic, Views render, Coordinators navigate
- ViewModels avoid `import SwiftUI`
- All API errors mapped through `AgriVisionError` enum with `userFacingMessage`

### 4.2 Navigation Flow

```
App Start → SplashView (2.5s)
  └─ Onboarding not seen? → OnboardingView (3 pages)
  └─ Not logged in? → AuthContainerView
  │   ├─ LoginView (email/password + Google)
  │   ├─ SignupView
  │   ├─ ForgotPasswordView
  │   └─ VerifyEmailView
  └─ No fields? → FieldSelectionCoordinator
  │   ├─ AddFieldIntroView
  │   ├─ FieldSelectionView (MKMapView + polygon drawing)
  │   ├─ FieldDetailsView (name, crop, dates, IoT)
  │   └─ SensorIntegrationView (pairing code)
  └─ Has fields → DashboardCoordinat
      └─ DashboardView (3 tabs)
          ├─ Home Tab: header, data sources, metric cards, alerts sheet
          ├─ Fields Tab: map with field cards
          └─ Settings Tab: profile, preferences, integrations, about
          └─ [Sheet] AIChatView (text + image chat)
          └─ [Sheet] FieldSelectionCoordinator (add field from dashboard)
```

### 4.3 All API Calls (20 endpoints)

All calls go through `APIClient` which adds `Authorization: Bearer` header, `X-Request-ID` header, automatic 401 retry with token refresh, ISO-8601 date decoding.

| # | Method | Endpoint | Request | Response | Service Function |
|---|--------|----------|---------|----------|-----------------|
| 1 | POST | `api/session/bootstrap` | — | `SessionBootstrap` | `bootstrapSession()` |
| 2 | GET | `api/fields` | query: `include_archived` | `[Field]` | `fetchFields()` |
| 3 | POST | `api/fields` | `FieldCreateRequest` | `Field` | `saveField()` |
| 4 | DELETE | `api/fields/{id}` | — | void | `deleteField()` |
| 5 | POST | `api/fields/{id}/data-refresh` | — | void | `refreshFieldData()` |
| 6 | GET | `api/fields/{id}/dashboard` | — | `DashboardSnapshot` | `fetchDashboard()` |
| 7 | GET | `api/fields/{id}/sensor-readings` | — | `[SensorReading]` | `fetchSensorReadings()` |
| 8 | GET | `api/fields/{id}/sensors` | — | `[FieldSensor]` | `fetchSensors()` |
| 9 | POST | `api/fields/{id}/sensors` | `SensorConfig` | `AssignedSensorResponse` | `assignSensor()` |
| 10 | GET | `api/fields/{id}/recommendations` | — | `[FieldRecommendation]` | `fetchRecommendations()` |
| 11 | POST | `api/fields/{id}/recommendations` | — | void | `refreshRecommendations()` |
| 12 | POST | `api/recommendations/{id}/feedback` | `{"status"}` | `FieldRecommendation` | `updateRecommendationFeedback()` |
| 13 | POST | `api/recommendations/{id}/outcome` | `{"outcome", "notes"?}` | `FieldRecommendation` | `recordRecommendationOutcome()` |
| 14 | GET | `api/fields/{id}/chat` | — | `[ChatMessage]` | `fetchChatHistory()` |
| 15 | POST | `api/fields/{id}/chat` | multipart (message + images) | `ChatTurn` | `sendChatMessage()` |
| 16 | GET | `api/fields/{id}/chat/attachments/{id}` | — | `Data` | `fetchChatAttachment()` |
| 17 | GET | `api/sensors/verify/{deviceId}` | — | `VerifyResponse` | `verifySensorConnection()` |
| 18 | POST | `api/sensors/pair` | `{"device_id"}` | `PairSensorResponse` | `pairSensor()` |
| 19 | GET | `api/fields/{id}/satellite/latest/{ndvi\|truecolor}` | — | `Data` (image) | `fetchSatelliteImage()` |
| 20 | GET | `api/fields/{id}/weather-soil` | — | `FieldWeatherSoil` | `fetchWeatherSoil()` |

### 4.4 Key Models

| Model | Fields |
|-------|--------|
| `Field` | id, name, coordinates, cropType, areaHa, status, agroStatus, latestNdvi, createdAt |
| `SessionBootstrap` | user (BackendUser), fields ([Field]), activeFieldLimit, activeFieldCount |
| `DashboardSnapshot` | field, sources (satellite, soil, weather, uvi, sensors), advisor, recommendations |
| `SourceState` | status, lastUpdated, data, message, retryable |
| `SensorReading` | time, temperature, moisture, humidity, ph, ec, npkN, npkP, npkK |
| `FieldRecommendation` | id, category, priority, advice, rationale, confidence, evidence, status, outcome |
| `ChatMessage` | id, role, content, attachments, createdAt |
| `ChatAttachment` | id, mimeType, byteSize, width, height, url |
| `FieldWeatherSoil` | soil (moisture, surfaceTemp, depthTemp), weather (current + forecast) |

### 4.5 Dependencies

- **Firebase iOS SDK** — FirebaseAuth, FirebaseAnalytics, FirebaseCore
- **Google Sign-In** — GoogleSignIn, GoogleSignInSwift
- **Swift Charts** — iOS 16+ (dashboard metrics visualization)
- **MapKit** — Field polygon selection
- **PhotosUI** — Image picker for chat

---

## 5. ESP32 Firmware

### 5.1 Build Environments

Two environments in `platformio.ini`:

#### Dev: `esp32s3_n16r8_AgriVision`
- Compile flag: none (no `PROD_MODE`)
- Libraries: ArduinoJson, OneWire, DallasTemperature, Adafruit NeoPixel
- Behavior: reads sensors, prints JSON to USB serial every 30s (`delay(30000)`)
- Use with `serial_to_mqtt_bridge.py`

#### Prod: `esp32s3_n16r8_AgriVision-prod`
- Compile flag: `-D PROD_MODE`
- Additional library: `PubSubClient` (MQTT)
- Behavior: WiFi auto-reconnect, MQTT publish, OTA updates, non-blocking `millis()` loop

### 5.2 Data Flow

```
                  Dev Mode                          Prod Mode
ESP32:       serial.print(json)              mqttClient.publish(topic, json)
                  │                                  │
                  ▼                                  ▼
        serial_to_mqtt_bridge.py              Mosquitto MQTT Broker
        (reads USB, publishes MQTT)           (direct MQTT over WiFi)
                  │                                  │
                  └──────────────┬───────────────────┘
                                 ▼
                    FastAPI Backend (MQTT consumer)

```

### 5.3 Sensor Readings

**Hardware:**
- Moisture sensor on pin 5 (analog, 12-bit, 10-sample averaging)
- Temperature sensor (DS18B20) on pin 6 (OneWire protocol, DallasTemperature library)

**Data format (JSON):**
```json
{"device_id":"ESP32_XXXXXX","temperature":25.4,"moisture":62.1}
```

**Calibration:**
- `DRY_VALUE = 4095` (dry soil analog reading)
- `WET_VALUE = 1200` (wet soil analog reading)
- Moisture % = `map(raw, DRY, WET, 0, 100)` clamped to 0-100

### 5.4 Device Identity

- If `DEVICE_ID` in config.h is non-empty → use it
- If empty (prod mode) → auto-generate from MAC: `ESP32_XXXXXX` (last 3 bytes of MAC)
- If empty (dev mode) → fallback: `ESP32_FIELD_NODE_1`

---

## 6. Infrastructure

### 6.1 Docker Compose (6 services)

| Service | Image | Port(s) | Purpose |
|---------|-------|---------|---------|
| `db` | timescale/timescaledb-ha:pg15-all | 5432 | PostgreSQL + PostGIS + TimescaleDB |
| `redis` | redis:alpine | — | Reserved for future scaling |
| `mqtt` | eclipse-mosquitto:latest | 1883 | MQTT message broker |
| `pgadmin` | dpage/pgadmin4:8.14 | 5050 | DB management (profile: tools) |
| `backend` | (builds from Dockerfile) | 8000 | FastAPI application |
| `portainer` | portainer/portainer-ce:latest | 9000, 9443 | Container management (profile: tools) |

**Service dependencies:** backend → db (healthcheck) + redis + mqtt

### 6.2 Networks & Volumes

**Network:** `agrivision_net` (bridge) — all services communicate internally

**Named volumes:**
| Volume | Mount |
|--------|-------|
| `postgres_data` | `/home/postgres/pgdata/data` |
| `mosquitto_data` | `/mosquitto/data` |
| `portainer_data` | `/data` |
| `agro_media` | `/app/media/agro` |
| `chat_media` | `/app/media/chat` |

**Bind mounts (backend):**
- `./app:/app/app` — live code reload
- `./alembic:/app/alembic` — migration files
- `firebase-credentials.json` (read-only)
- `google-application-credentials.json` (read-only)

### 6.3 Dockerfile

- Base: `python:3.11-slim`
- System packages: `build-essential`, `libpq-dev` (for psycopg2)
- Python packages from `requirements.txt`
- Non-root user `appuser` (UID 1000)
- Runs: `uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload`

### 6.4 Dependencies (requirements.txt)

```
fastapi, uvicorn[standard]
sqlalchemy, psycopg2-binary, alembic
geoalchemy2
firebase-admin
httpx
paho-mqtt
google-genai
Pillow
pydantic, pydantic-settings
python-dotenv
```

---

## 7. Development Tools & Scripts

### `scripts/serial_to_mqtt_bridge.py`
Development bridge that reads sensor JSON from ESP32 USB serial and forwards to MQTT.

- Serial port: `/dev/cu.usbserial-A5069RR4` @ 115200 baud
- MQTT broker: `localhost:1883`
- Auto-detects JSON lines (ignores boot logs)
- Topic: `agrivision/sensors/{device_id}/readings`

### Testing
- **150 tests** across 21 files
- Run: `pytest tests/` (requires Docker PostgreSQL for integration tests)
- 6 test categories: unit (mocked DB), integration (real DB), Pydantic validation, scheduler sync, scheduler AI, sensor aggregation, MQTT, media storage, rate limit, chat, evaluation dataset

---

## 8. End-to-End Data Flows

### 8.1 IoT Sensor → Dashboard

```
ESP32 reads sensors (temp + moisture)
  → prints JSON to serial (dev) / publishes MQTT (prod)
  → serial_to_mqtt_bridge.py (dev) / Mosquitto (prod)
  → FastAPI on_message validates + enqueues
  → _db_writer_loop batch-writes to sensor_readings
  → _aggregation_loop creates hourly summaries
  → iOS DashboardView calls GET /api/fields/{id}/dashboard
  → dashboard endpoint queries sensor_readings (latest 50)
  → displayed in SensorLiveCardView, MoistureCardView, etc.
```

### 8.2 Field Creation → Satellite Data → AI Analysis

```
iOS: Farmer draws polygon on map
  → FieldDetailsView (name, crop, dates)
  → POST /api/fields
  → Backend: validates polygon (WKT, area, limit)
  → creates Field record
  → sync_field_initial() → _ensure_polygon() → creates AgroMonitoring polygon
  → sync_field_once() → _sync_satellite() → search_latest_scene + get_index_statistics + cache_scene_image
  → _sync_soil() + _sync_weather() + _sync_uvi()
  → run_ai_by_field_id() → run_ai_for_field()
  → builds context, calls Gemini AI
  → stores recommendations
  → iOS: DashboardView shows satellite card, weather, soil, AI cards
```

### 8.3 AI Chat with Image

```
iOS: Farmer types message + attaches photo
  → POST /api/fields/{id}/chat (multipart, with Idempotency-Key)
  → Backend: validates, sanitizes image (strip EXIF, re-encode JPEG)
  → acquires advisory lock for idempotency
  → loads field context + chat history
  → calls Gemini AI (chat endpoint)
  → stores message pair + attachments
  → iOS: displays ChatBubble with image
```

### 8.4 Field Deletion Cleanup

```
iOS: Farmer taps "Delete Field"
  → DELETE /api/fields/{id}
  → Backend: marks field as "deleting", deletes sensor assignments
  → creates FieldDeletionJob (status: pending)
  → returns 204 immediately
  → Background: process_field_deletion_job()
  → deletes AgroMonitoring polygon
  → removes satellite media directory
  → removes chat media files
  → marks job as completed
  → Retries with exponential backoff on failure
```

### 8.5 Background Sync Cycle (every 5 minutes)

```
external_data_loop()
  └─ For each active field:
      ├─ _sync_satellite()  (if due per field.interval_overrides.satellite_hours)
      ├─ _sync_soil()       (if due per field.interval_overrides.soil_hours)
      ├─ _sync_weather()    (if due per field.interval_overrides.weather_hours)
      ├─ _sync_uvi()        (if due per field.interval_overrides.uvi_hours)
      └─ _sync_accumulations() (if due per field.interval_overrides.weather_hours)
  └─ For each field: run_ai_for_field() (if due per field.interval_overrides.ai_hours)
  └─ process_pending_field_deletions()
```

### 8.6 Free Mode vs Paid Mode

**Free Mode** (`AGRO_FREE_MODE=true`):
- Weather, soil, current UVI, satellite imagery — all work
- UVI forecast — skipped (returns 401 from AgroMonitoring)
- Accumulated temperature/precipitation — skipped, derived from cached weather data
- Derived GDD formula: `sum(max(temp - 10°C, 0) * hours / 24)` over 7-day window

**Paid Mode** (`AGRO_FREE_MODE=false`, requires paid AgroMonitoring tier):
- UVI forecast — attempted, capability tracked per field
- Accumulated temperature/precipitation — attempted via history endpoint
- Falls back to derived estimates if paid endpoints return 401/402/403

---

## 9. Total Lines of Code

| Component | Lines | Language |
|-----------|-------|----------|
| **Backend** | ~3,730 | Python |
| **iOS App** | ~9,875 | Swift |
| **ESP32 Firmware** | ~210 | C++ |
| **Infrastructure** | ~200 | YAML, Dockerfile, TOML |
| **Documentation** | ~6,000 | Markdown |
| **Tests** | ~3,795 | Python |
| **Total** | **~23,810** | |
