# 6. Entity Relationship Diagram (ERD)

## 6.1 Comprehensive 22-Entity Relational & Time-Series ERD
The AgriVision persistence layer is implemented on PostgreSQL 15 (`timescale/timescaledb-ha:pg15-all`) with the PostGIS spatial extension and the TimescaleDB time-series engine. The schema encompasses 22 distinct entities modeling users, fields, hardware sensors, satellite imagery, AI reasoning runs, and clinical expert validations.

```mermaid
erDiagram
    USERS {
        PG_UUID id
        String firebase_uid
        String email
        Enum role
        DateTime created_at
    }
    INVITATIONS {
        PG_UUID id
        String email
        Enum role
        String status
        PG_UUID invited_by_id
        DateTime created_at
    }
    FIELDS {
        PG_UUID id
        PG_UUID owner_id
        String name
        String crop_type
        DateTime plantation_date
        DateTime expected_harvest_date
        Geometry boundary
        Float area_ha
        String status
        DateTime archived_at
        DateTime created_at
        DateTime updated_at
        Float latest_ndvi
        JSONB interval_overrides
        Float latest_health_score
        String latest_health_label
        Text latest_health_rationale
        DateTime latest_health_updated_at
    }
    FIELD_PROVIDER_LINKS {
        PG_UUID id
        PG_UUID field_id
        String provider
        String external_id
        String sync_status
        String sync_error
        Boolean retryable
        DateTime last_sync_at
        DateTime created_at
        DateTime updated_at
    }
    SENSORS {
        PG_UUID id
        PG_UUID owner_id
        PG_UUID field_id
        String device_id
        String name
        String sensor_type
        Float battery_level
        DateTime last_seen
    }
    SENSOR_READINGS {
        DateTime time
        PG_UUID sensor_id
        Float temperature
        Float moisture
        Float humidity
        Float ph
        Float ec
        Float npk_n
        Float npk_p
        Float npk_k
    }
    FIELD_OBSERVATIONS {
        PG_UUID id
        PG_UUID field_id
        String source
        String metric
        Float value
        String unit
        JSONB payload
        DateTime observed_at
        DateTime fetched_at
        DateTime expires_at
    }
    SATELLITE_SCENES {
        PG_UUID id
        PG_UUID field_id
        String provider_scene_id
        String provider
        String source_type
        DateTime acquired_at
        Float cloud_percent
        Float coverage_percent
        JSONB statistics
        String ndvi_image_path
        String truecolor_image_path
        DateTime created_at
    }
    AI_ANALYSIS_RUNS {
        PG_UUID id
        PG_UUID field_id
        String provider
        String status
        JSONB context_snapshot
        String context_fingerprint
        String model_name
        String prompt_version
        String policy_version
        String data_quality
        JSONB evidence
        String error
        DateTime started_at
        DateTime completed_at
    }
    FIELD_RECOMMENDATIONS {
        PG_UUID id
        PG_UUID field_id
        PG_UUID analysis_run_id
        String category
        String priority
        Text advice
        Text rationale
        Float confidence
        String confidence_reason
        String safety_level
        Boolean requires_expert_confirmation
        JSONB evidence
        String expert_status
        Text expert_notes
        String status
        Float ndvi_at_generation
        DateTime created_at
        DateTime feedback_at
        DateTime expires_at
        String outcome
        Text outcome_notes
        DateTime outcome_at
        PG_UUID reviewed_by_id
        DateTime reviewed_at
    }
    AI_CHAT_THREADS {
        PG_UUID id
        PG_UUID field_id
        String channel
        Text rolling_summary
        DateTime summarized_through
        DateTime created_at
        DateTime updated_at
    }
    FIELD_SEASON_MEMORIES {
        PG_UUID id
        PG_UUID field_id
        DateTime season_started_at
        DateTime season_ended_at
        Text narrative
        JSONB key_events
        DateTime created_at
        DateTime updated_at
    }
    AI_CHAT_MESSAGES {
        PG_UUID id
        PG_UUID thread_id
        PG_UUID reply_to_message_id
        String role
        Text content
        String idempotency_key
        String status
        DateTime created_at
    }
    CHAT_ATTACHMENTS {
        PG_UUID id
        PG_UUID message_id
        String storage_key
        String mime_type
        Integer byte_size
        Integer width
        Integer height
        String sha256
        DateTime created_at
    }
    PROVIDER_CAPABILITIES {
        PG_UUID id
        String provider
        String capability
        PG_UUID field_id
        String status
        Integer status_code
        DateTime checked_at
        String detail
    }
    PROVIDER_REQUEST_LOGS {
        PG_UUID id
        String provider
        String endpoint
        PG_UUID field_id
        String outcome
        Integer status_code
        Boolean cache_hit
        Integer duration_ms
        DateTime created_at
    }
    PROVIDER_CACHE {
        String cache_key
        String provider
        String endpoint
        PG_UUID field_id
        JSONB response_payload
        DateTime created_at
        DateTime expires_at
    }
    FIELD_DELETION_JOBS {
        PG_UUID id
        PG_UUID field_id
        String provider_polygon_id
        JSONB media_paths
        String status
        Integer attempts
        String last_error
        DateTime next_attempt_at
        DateTime created_at
        DateTime completed_at
    }
    SENSOR_READINGS_HOURLY {
        DateTime bucket
        PG_UUID sensor_id
        Float temperature_avg
        Float temperature_min
        Float temperature_max
        Float moisture_avg
        Float moisture_min
        Float moisture_max
        Float humidity_avg
        Float humidity_min
        Float humidity_max
        Float ph_avg
        Float ph_min
        Float ph_max
        Float ec_avg
        Float ec_min
        Float ec_max
        Float npk_n_avg
        Float npk_n_min
        Float npk_n_max
        Float npk_p_avg
        Float npk_p_min
        Float npk_p_max
        Float npk_k_avg
        Float npk_k_min
        Float npk_k_max
        Integer reading_count
    }
    AGRONOMY_KNOWLEDGE_DOCUMENTS {
        PG_UUID id
        String external_id
        String title
        String source_url
        String crop
        String region
        String version
        DateTime published_at
        Boolean approved
        DateTime created_at
    }
    USER_NOTIFICATIONS {
        PG_UUID id
        PG_UUID user_id
        PG_UUID field_id
        PG_UUID created_by_id
        String title
        Text body
        String priority
        String category
        String reference_id
        String reference_type
        Boolean is_read
        DateTime created_at
    }
    SYSTEM_SETTINGS {
        PG_UUID id
        String key
        JSONB value
        DateTime updated_at
        PG_UUID updated_by
    }
    USERS ||--o{ FIELDS : owns
    USERS ||--o{ SENSORS : registers
    USERS ||--o{ INVITATIONS : sends
    USERS ||--o{ USER_NOTIFICATIONS : receives
    USERS ||--o{ FIELD_RECOMMENDATIONS : reviews
    USERS ||--o{ SYSTEM_SETTINGS : updates
    FIELDS ||--o{ SENSORS : contains
    FIELDS ||--o{ FIELD_PROVIDER_LINKS : links
    FIELDS ||--o{ FIELD_OBSERVATIONS : has
    FIELDS ||--o{ SATELLITE_SCENES : monitored_by
    FIELDS ||--o{ AI_ANALYSIS_RUNS : analyzed_by
    FIELDS ||--o{ FIELD_RECOMMENDATIONS : receives
    FIELDS ||--o{ FIELD_SEASON_MEMORIES : tracks
    FIELDS ||--o{ AI_CHAT_THREADS : has_discussions
    FIELDS ||--o{ PROVIDER_CAPABILITIES : has
    FIELDS ||--o{ PROVIDER_REQUEST_LOGS : logs
    FIELDS ||--o{ PROVIDER_CACHE : caches
    FIELDS ||--o{ USER_NOTIFICATIONS : concerns
    FIELDS ||--o{ FIELD_DELETION_JOBS : deletes
    SENSORS ||--o{ SENSOR_READINGS : generates
    SENSORS ||--o{ SENSOR_READINGS_HOURLY : aggregates
    AI_ANALYSIS_RUNS ||--o{ FIELD_RECOMMENDATIONS : produces
    AI_CHAT_THREADS ||--o{ AI_CHAT_MESSAGES : contains
    AI_CHAT_MESSAGES ||--o{ CHAT_ATTACHMENTS : attachments
    AI_CHAT_MESSAGES ||--o{ AI_CHAT_MESSAGES : replies_to
```

## 6.2 Entity Relationships & Multiplicity Analysis
* **`users` -> `fields` (1 : N):** A farmer user owns zero or more field parcels. Enforced via foreign key `fields.owner_id -> users.id`.
* **`users` -> `invitations` (1 : N):** System administrators issue zero or more staff invitations to agronomists via `invitations.invited_by_id`.
* **`fields` -> `sensors` (1 : N):** A field contains zero or more stationed IoT hardware nodes via `sensors.field_id`.
* **`sensors` -> `sensor_readings` (1 : N):** A sensor transmits continuous time-series samples stored in TimescaleDB hypertable partitioned across 7-day chunks.
* **`sensors` -> `sensor_readings_hourly` (1 : N):** Hourly statistical buckets keyed by the composite primary key `(bucket, sensor_id)`, maintained by an idempotent application-level upsert worker rather than a TimescaleDB continuous aggregate.
* **`fields` -> `satellite_scenes` (1 : N):** A field accumulates periodic satellite acquisitions fetched from Sentinel-2 via AgroMonitoring.
* **`fields` -> `ai_analysis_runs` (1 : N):** Each autonomous reasoning cycle creates an analysis run recording context snapshots, fingerprints, and model versions.
* **`ai_analysis_runs` -> `field_recommendations` (1 : N):** An analysis run synthesizes zero or more actionable recommendations.
* **`fields` -> `field_season_memories` (1 : N, one active):** A rolling seasonal narrative accumulating milestone memory across the crop growth cycle. Closed seasons are retained as history; a partial unique index on `field_id WHERE season_ended_at IS NULL` guarantees at most one *open* season memory per field.
* **`fields` -> `ai_chat_threads` (1 : N, one per channel):** A `UNIQUE (field_id, channel)` constraint gives each field exactly one persistent thread per audience — a `farmer` channel and an `agronomist` channel — so staff discussion never leaks into the farmer's conversation.
* **`users` -> `sensors` (1 : N):** Every paired hardware node records the owner who claimed it via `sensors.owner_id`, which is what scopes fleet queries by tenant.
* **`users` -> `field_recommendations` (1 : N, as reviewer):** `reviewed_by_id` and `reviewed_at` form the clinical audit trail — any recommendation that can gate a chemical intervention carries a reviewer of record.
* **`fields` / `users` -> `user_notifications` (1 : N):** A notification names the field it concerns (`field_id`) and, when staff-authored, its sender (`created_by_id`), so advice that can gate an intervention is always attributable.
* **`fields` -> `field_deletion_jobs` (logical 1 : N):** Deletion jobs deliberately carry `field_id` **without** a foreign-key constraint, because the job must outlive the row it references in order to finish removing the external provider polygon and cached media.
* **`ai_chat_threads` -> `ai_chat_messages` (1 : N):** A chat thread contains ordered messages exchanged between user and assistant.
* **`ai_chat_messages` -> `chat_attachments` (1 : N):** User messages may include zero or more sanitized image attachments.

---

# 7. Architecture Design Diagram

## 7.1 High-Level Multi-Tier Layered Architecture Diagram
The platform architecture follows a decoupled, async-first pattern. Three long-running background tasks are started from the FastAPI lifespan hook — the MQTT ingestion writer, the external-data (satellite/weather/soil) sync worker, and the hourly aggregation worker — so that broker traffic, third-party provider latency and LLM reasoning never sit on a client request path.

```mermaid
graph TD
    subgraph Tier1 ["Tier 1 — Client Presentation"]
        iOS["Native iOS Client (SwiftUI, MVVM-C)<br/>Splash - Onboarding - Auth - Dashboard<br/>FieldSelection - Fields - AIChat<br/>SensorIntegration - Settings"]
        Web["Web GIS Workstation (React 19 + Vite)<br/>GISMapView - AIAdvisoryView - IoTHardwareView<br/>FleetAnalyticsView - UsersView - SettingsView<br/>LoginView - InviteAcceptView"]
    end

    subgraph Tier2 ["Tier 2 — Edge Devices"]
        ESP["ESP32-S3 Sensor Node (Arduino/PlatformIO)<br/>Moisture GPIO 5 - DS18B20 GPIO 6"]
        Broker["Eclipse Mosquitto Broker<br/>agrivision/sensors/+/readings"]
        ESP -->|"MQTT publish, 5 s cadence"| Broker
    end

    subgraph Tier3 ["Tier 3 — FastAPI Application Gateway"]
        Auth["Firebase JWT Auth + RBAC<br/>core/auth.py, core/rate_limit.py"]
        Routers["13 API Routers<br/>session - fields - sensors - recommendations<br/>chat - agronomist - satellite - export<br/>invitations - admin - notifications - advisories"]
        Auth --> Routers
    end

    subgraph Tier4 ["Tier 4 — Domain Services & Background Workers"]
        SvcAgro["agromonitoring_service<br/>polygon registration, scenes, tiles, weather"]
        SvcAI["ai_advisor_service<br/>Gemini provider, RAG, safety policy"]
        SvcMedia["chat_media_service<br/>EXIF strip, JPEG re-encode, storage"]
        SvcMQTT["mqtt_service<br/>subscribe, validate, queue, batch write"]
        SvcSched["scheduler<br/>external_data_loop, AI reasoning,<br/>hourly rollup, retention purge, deletion jobs"]
    end

    subgraph Tier5 ["Tier 5 — Persistence"]
        Rel[("PostgreSQL 15 relational core<br/>users, fields, sensors, invitations,<br/>field_recommendations, user_notifications,<br/>system_settings")]
        Geo[("PostGIS spatial<br/>fields.boundary GEOMETRY(Polygon, 4326)")]
        TS[("TimescaleDB hypertable<br/>sensor_readings + sensor_readings_hourly")]
        Media[("Private media volumes<br/>media/agro, media/chat")]
    end

    subgraph Tier6 ["Tier 6 — External Cloud Services"]
        FB["Firebase Authentication"]
        AgroAPI["AgroMonitoring REST API<br/>(Sentinel-2 imagery, weather, soil, UVI)"]
        VertexAI["Vertex AI — Gemini multimodal LLM"]
        VertexSearch["Vertex AI Search — agronomy RAG datastore"]
    end

    iOS -->|"HTTPS REST, Bearer ID token"| Auth
    Web -->|"HTTPS REST, Bearer ID token"| Auth
    Auth -.->|"verify_id_token"| FB

    Routers --> SvcAgro
    Routers --> SvcAI
    Routers --> SvcMedia
    Routers --> SvcSched

    Broker -->|"subscribe"| SvcMQTT

    SvcMQTT --> TS
    SvcSched --> TS
    SvcSched --> Rel
    SvcAgro --> Rel
    SvcAgro --> Media
    SvcAI --> Rel
    SvcMedia --> Media
    Routers --> Rel
    Routers --> Geo

    SvcAgro -->|"HTTPS"| AgroAPI
    SvcAI -->|"google-genai SDK"| VertexAI
    SvcAI -->|"Discovery Engine"| VertexSearch
```

## 7.2 Low-Level Deployment & Container Topology Diagram
The entire backend suite is containerized and orchestrated via Docker Compose on an isolated bridge network (`agrivision_net`), isolating sensitive database and MQTT traffic from public exposure.

```mermaid
flowchart TD
    subgraph Client_Access_Tier ["1. Client Access Tier"]
        iOS_Client["Native iOS Client (iPhone / Simulator)<br/>SwiftUI / Apple MapKit"]
        Web_Client["Desktop Web Browser Workstation<br/>React 19 / Vite / MapLibre GL"]
    end

    subgraph Docker_Bridge_Network ["2. Docker Container Network (agrivision_net)"]
        subgraph Frontend_Container ["Web Presentation Service"]
            Nginx_Web["Nginx (multi-stage Node 22 build)<br/>Host: 3000 / Container: 80"]
        end

        subgraph Backend_Container ["Application API Gateway"]
            FastAPI_Svc["FastAPI Application Server<br/>Python 3.11-slim / Uvicorn ASGI<br/>Host: 127.0.0.1:8000 / Internal: 8000"]
        end

        subgraph Database_Container ["TimescaleDB High-Availability Database"]
            DB_Svc["PostgreSQL 15 + PostGIS + TimescaleDB<br/>timescale/timescaledb-ha:pg15-all<br/>Host: 127.0.0.1:5432 / Internal: 5432<br/>pg_isready healthcheck gates dependents"]
        end

        subgraph MQTT_Container ["Mosquitto MQTT Message Broker"]
            Mosquitto_Svc["Eclipse Mosquitto Broker<br/>Host: 127.0.0.1:1883 / Internal: 1883"]
        end

        subgraph Management_Tools ["Management Tools Profile"]
            PGAdmin_Svc["pgAdmin 4.8.14 Database UI<br/>profile: tools<br/>Host: 127.0.0.1:5050 / Internal: 80"]
            Portainer_Svc["Portainer CE Container Manager<br/>profile: tools<br/>Host: 127.0.0.1:9000 and 9443"]
        end

        subgraph Named_Volumes ["Docker Persistent Named Storage"]
            vol_db[("Volume: postgres_data<br/>Relational Tables, PostGIS Geometry & Hypertables")]
            vol_agro[("Volume: agro_media<br/>Cached NDVI & True-Colour Rasters")]
            vol_chat[("Volume: chat_media<br/>Sanitised Chat Photographs")]
            vol_mqtt[("Volume: mosquitto_data<br/>Broker Persistence")]
        end
    end

    subgraph Hardware_Edge_Tier ["3. Edge IoT Hardware Tier"]
        ESP32_Node["ESP32-S3 Sensor Node (Field Deployment)<br/>Pin 5: Analog Soil Moisture<br/>Pin 6: DS18B20 1-Wire Ground Temperature"]
        Serial_Gateway["Local Serial Bridge Gateway<br/>/dev/cu.usbserial to MQTT Publisher"]
    end

    subgraph External_Cloud_Tier ["4. External Cloud Services & APIs"]
        Firebase_Auth["Firebase Authentication<br/>(User Identity Pool & JWT Issuance)"]
        Agro_API["AgroMonitoring REST API<br/>(Sentinel-2 Multispectral Tiles & Weather)"]
        Vertex_Gemini["Google Cloud Vertex AI<br/>(Gemini multimodal LLM, GOOGLE_AI_MODEL)"]
        Vertex_Search["Vertex AI Search Discovery Engine<br/>(Agronomy RAG Knowledge Base)"]
    end

    Web_Client -->|"HTTP :3000"| Nginx_Web
    Web_Client -->|"REST API Bearer JWT :8000"| FastAPI_Svc
    iOS_Client -->|"REST API Bearer JWT :8000"| FastAPI_Svc

    ESP32_Node -->|"UART Serial 115200"| Serial_Gateway
    Serial_Gateway -->|"TCP :1883"| Mosquitto_Svc
    ESP32_Node -.->|"Direct WiFi MQTT :1883"| Mosquitto_Svc

    FastAPI_Svc -->|"TCP :1883 MQTT Ingestion Worker"| Mosquitto_Svc
    FastAPI_Svc -->|"TCP :5432 SQLAlchemy 2.0 Pool"| DB_Svc

    DB_Svc --- vol_db
    FastAPI_Svc --- vol_agro
    FastAPI_Svc --- vol_chat
    Mosquitto_Svc --- vol_mqtt

    FastAPI_Svc -->|"Verify JWT Tokens"| Firebase_Auth
    FastAPI_Svc -->|"HTTPS :443 google-genai SDK"| Vertex_Gemini
    Vertex_Gemini -.->|"Grounded Agronomic Search"| Vertex_Search

```

## 7.3 Detailed Architectural Tier Breakdown

### 1. Client Presentation Tier
* **Native iOS Mobile App:** Built using Swift, SwiftUI, Combine and Apple MapKit on an MVVM-C architecture. Session persistence is handled by the Firebase iOS SDK; user preferences (saved email, dashboard refresh interval, onboarding state) are stored in `UserDefaults` behind injected service protocols.
* **Enterprise Web GIS Workstation:** Built using React 19, Vite, TypeScript, Tailwind CSS 4 and MapLibre GL, with TanStack Query for server state and Zustand for client state. Features interactive GIS inspection of the multi-spectral raster layers served for the active scene, hardware fleet pairing, analytics charts and the agronomist advisory review queue.

### 2. Edge Sensing & IoT Hardware Tier
* **ESP32-S3 Microcontroller:** Deployed in physical fields on an `esp32-s3-devkitc-1-n16r8` board, interfaced with an analog resistive soil-moisture probe (12-bit ADC on GPIO 5, averaged across samples with open-circuit and short-circuit fault thresholds) and a Dallas DS18B20 1-Wire temperature sensor on GPIO 6.
* **Non-Blocking Firmware Stack:** Programmed in C++ against the Arduino framework via PlatformIO. A single `loop()` drives millis-scheduled publishing every 5 seconds, a non-blocking WiFi and MQTT reconnect state machine, OTA firmware update, a NeoPixel status indicator, and telemetry suppression when no probe returns a valid reading.
* **Serial UART Bridge:** Supports a local serial bridge (`/dev/cu.usbserial` at 115200 baud) for tethered bench testing and development.

### 3. Ingestion & Message Broker Tier
* **Eclipse Mosquitto:** MQTT broker handling device telemetry on the topic pattern `agrivision/sensors/{device_id}/readings` (subscribed as `agrivision/sensors/+/readings`) on port 1883, with optional username/password authentication.
* **Async Ingestion Worker:** Long-running Paho-MQTT consumer running on a daemon thread that validates each payload (topic/`device_id` agreement, 5-minute clock-skew bound, per-device flood limit of 120 messages per 60 seconds), hands accepted samples to an `asyncio.Queue`, and drains that queue in batches of up to 50 rows written with `ON CONFLICT (time, sensor_id)` handling.
* **Hourly Rollup Engine:** In-process worker (started from the FastAPI lifespan) that upserts Min/Max/Avg/Count aggregates for the trailing 24 hours into `sensor_readings_hourly` every hour, and prunes raw readings once daily at 03:00 UTC beyond the retention window (14 days by default, per-field overridable).

### 4. Application Services & Business Logic Tier
* **FastAPI Gateway (:8000):** Uvicorn-hosted asynchronous ASGI application serving REST endpoints, protected by Firebase JWT authentication middleware.
* **Agromonitoring Satellite Service:** Handles external polygon registration, weather forecast caching, and dynamic multi-spectral raster tile streaming.
* **AI Advisor Service & Scheduler:** Executes the autonomous reasoning loop, computes holistic field health scores (0–100 with a categorical label and rationale, or `insufficient_data` rather than a fabricated number), applies the chemical/dosage safety policy, and maintains the pending expert-review queue.
* **Chat Media Sanitization Service:** Strips GPS/EXIF metadata from uploaded crop photographs, applies EXIF orientation, converts to RGB, downscales to a maximum edge of 2,048 px, re-encodes as progressive JPEG with no EXIF block, and stores the result on a private local volume or a GCS bucket behind a storage abstraction.

### 5. Persistence & Enterprise Storage Tier
* **PostgreSQL 15 + PostGIS:** Stores relational user profiles, fields, invitations, recommendations, notifications and settings, plus spatial vector geometries (`GEOMETRY(Polygon, 4326)`).
* **TimescaleDB Engine:** Powers the `sensor_readings` hypertable created at startup via `create_hypertable(..., if_not_exists => TRUE, migrate_data => TRUE)`, which partitions along `time` using TimescaleDB's default 7-day chunk interval.
* **Persistent Docker Volumes:** Named volumes (`postgres_data`, `agro_media`, `chat_media`, `mosquitto_data`, `portainer_data`) preserve state across container restarts and rebuilds.

### 6. External Cloud & Foundation AI Tier
* **Google Cloud Vertex AI (Gemini):** Multimodal foundation model performing crop-disease diagnosis and autonomous reasoning. The model is configuration-driven (`GOOGLE_AI_MODEL`, default `gemini-3.7-flash`) and can be re-pointed at runtime through the admin AI settings endpoint without redeployment.
* **Vertex AI Search (Discovery Engine):** Serves as the RAG knowledge store, indexing certified agronomy extension documents for grounded advice.
* **Firebase Authentication:** Handles user identity pools, password resets, and cryptographically signed JWT issuance.
