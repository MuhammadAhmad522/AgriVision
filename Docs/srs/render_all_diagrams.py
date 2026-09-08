#!/usr/bin/env python3
"""
render_all_diagrams.py
Renders all 13 system diagrams to high-resolution PNG and SVG formats using mermaid.ink.
Every diagram is designed with balanced aspect ratios (top-down TD orientation)
to guarantee perfect readability in Markdown preview and document exports.
"""

import os
import base64
import urllib.request
import time

out_dir = "/Users/ahmad/AgriVision/Docs/srs/diagrams"
os.makedirs(out_dir, exist_ok=True)

diagrams = {
    "01_use_case_diagram": """flowchart LR
    subgraph Actors ["Users & Devices"]
        direction TB
        Farmer["Farmer (iOS Mobile)"]
        Agronomist["Agronomist (Web Portal)"]
        Admin["System Admin (Web Portal)"]
        ESP32["ESP32 IoT Node"]
    end

    subgraph System ["AgriVision Platform Boundary"]
        direction TB
        subgraph UC_Auth ["1. Identity & RBAC"]
            UC1(("Authenticate & Session"))
            UC2(("Manage Roles & Invites"))
        end
        subgraph UC_Geo ["2. Geospatial & Satellite"]
            UC3(("Draw Field Boundaries"))
            UC4(("Sync Satellite Imagery"))
            UC5(("8-Layer Spectral Rasters"))
        end
        subgraph UC_IoT ["3. IoT & Telemetry"]
            UC6(("Pair & Provision Sensors"))
            UC7(("Ingest Ground Telemetry"))
            UC8(("Hourly/Daily Rollups"))
        end
        subgraph UC_AI ["4. AI & HITL Safety"]
            UC9(("Multimodal Pathology Chat"))
            UC10(("Autonomous Reasoning Loop"))
            UC11(("Clinical Agronomist Review"))
            UC12(("Inject AI Steering Guidance"))
        end
        UC_Auth ~~~ UC_Geo
        UC_Geo ~~~ UC_IoT
        UC_IoT ~~~ UC_AI
    end

    subgraph Cloud ["External Cloud APIs"]
        direction TB
        AgroAPI["AgroMonitoring API"]
        GeminiAPI["Google Gemini 2.5 Flash"]
    end

    Farmer --- UC1
    Farmer --- UC3
    Farmer --- UC6
    Farmer --- UC9

    Agronomist --- UC1
    Agronomist --- UC5
    Agronomist --- UC11
    Agronomist --- UC12

    Admin --- UC1
    Admin --- UC2
    Admin --- UC6

    ESP32 --- UC7
    UC7 --> UC8

    UC3 --- AgroAPI
    UC4 --- AgroAPI
    UC5 --- AgroAPI

    UC9 --- GeminiAPI
    UC10 --- GeminiAPI
""",

    "02_gantt_schedule": """gantt
    title AgriVision 6-Month Engineering Schedule
    dateFormat  YYYY-MM-DD
    axisFormat  %b

    section Phase 1: Inception
    Requirements Discovery & SRS Spec      :done, p1_1, 2026-01-01, 14d
    System Architecture & PostGIS Schema   :done, p1_2, after p1_1, 14d
    Docker Setup (FastAPI, Postgres, MQTT) :done, p1_3, after p1_1, 14d

    section Phase 2: Ingestion
    ESP32 Sensor Firmware (Non-blocking)   :done, p2_1, 2026-02-01, 20d
    Mosquitto MQTT Broker & Ingestion Svc  :done, p2_2, after p2_1, 16d
    AgroMonitoring API & Polygon Sync      :done, p2_3, 2026-02-15, 20d

    section Phase 3: AI Engine
    Google Gemini Multimodal Diagnostics   :done, p3_1, 2026-03-01, 22d
    Autonomous Reasoning Loop & Fallbacks  :done, p3_2, after p3_1, 18d
    Chemical Safety Guardrails & Queues    :done, p3_3, after p3_2, 14d

    section Phase 4: Clients
    Native iOS Client (SwiftUI & MapKit)   :done, p4_1, 2026-03-15, 30d
    Web Portal (React 19 & MapLibre GIS)   :done, p4_2, 2026-03-25, 30d
    IoT Hardware Fleet & Staff RBAC Views  :done, p4_3, after p4_2, 16d

    section Phase 5: Verification
    End-to-End System Audit & Bug Fixes    :done, p5_1, 2026-05-01, 20d
    Automated Regression Tests (Pytest/iOS):done, p5_2, after p5_1, 15d

    section Phase 6: Release
    Comprehensive Documentation & SRS Pub  :active, p6_1, 2026-06-01, 15d
    Production Deployment & Capstone Demo  :p6_2, after p6_1, 15d
""",

    "03_database_erd": """erDiagram
    USERS ||--o{ FIELDS : "owns"
    USERS ||--o{ SENSORS : "owns"
    USERS ||--o{ INVITATIONS : "sends"
    USERS ||--o{ FIELD_RECOMMENDATIONS : "reviews"
    USERS ||--o{ USER_NOTIFICATIONS : "receives"

    FIELDS ||--o{ SENSORS : "contains"
    FIELDS ||--o{ SATELLITE_SCENES : "has"
    FIELDS ||--o{ FIELD_OBSERVATIONS : "has"
    FIELDS ||--o{ AI_ANALYSIS_RUNS : "evaluates"
    FIELDS ||--o{ FIELD_RECOMMENDATIONS : "receives"
    FIELDS ||--o| AI_CHAT_THREADS : "maintains"
    FIELDS ||--o| FIELD_SEASON_MEMORY : "accumulates"
    FIELDS ||--o{ FIELD_PROVIDER_LINKS : "syncs"

    SENSORS ||--o{ SENSOR_READINGS : "transmits"
    SENSORS ||--o{ SENSOR_READINGS_HOURLY : "aggregates"

    AI_ANALYSIS_RUNS ||--o{ FIELD_RECOMMENDATIONS : "generates"
    AI_CHAT_THREADS ||--o{ AI_CHAT_MESSAGES : "contains"
    AI_CHAT_MESSAGES ||--o{ CHAT_ATTACHMENTS : "includes"

    USERS {
        uuid id PK
        string firebase_uid UK
        string email UK
        string display_name
        string role
        boolean is_active
        datetime created_at
    }

    INVITATIONS {
        uuid id PK
        string email
        string role
        string status
        string token UK
        uuid invited_by_id FK
        datetime created_at
        datetime expires_at
    }

    FIELDS {
        uuid id PK
        uuid owner_id FK
        string name
        string crop_type
        geometry boundary
        float area_ha
        string status
        string agromonitoring_polygon_id
        string agro_status
        float latest_ndvi
        float latest_health_score
        string latest_health_label
        datetime created_at
    }

    SENSORS {
        uuid id PK
        uuid owner_id FK
        uuid field_id FK
        string device_id UK
        string name
        string sensor_type
        float battery_level
        datetime last_seen
        datetime created_at
    }

    SENSOR_READINGS {
        datetime time PK
        uuid sensor_id PK,FK
        float temperature
        float moisture
        float humidity
        float ph
        float ec
        float npk_n
        float battery_level
    }

    SENSOR_READINGS_HOURLY {
        datetime bucket PK
        uuid sensor_id PK,FK
        float temperature_avg
        float moisture_avg
        float humidity_avg
        integer reading_count
    }

    SATELLITE_SCENES {
        uuid id PK
        uuid field_id FK
        string provider_scene_id
        datetime acquired_at
        float cloud_percent
        string ndvi_image_path
        datetime created_at
    }

    FIELD_RECOMMENDATIONS {
        uuid id PK
        uuid field_id FK
        uuid analysis_run_id FK
        string category
        string priority
        text advice
        float confidence
        string expert_status
        uuid reviewed_by_id FK
        datetime reviewed_at
        datetime created_at
    }

    AI_CHAT_MESSAGES {
        uuid id PK
        uuid thread_id FK
        string role
        text content
        datetime created_at
    }

    FIELD_SEASON_MEMORY {
        uuid id PK
        uuid field_id FK
        text narrative
        datetime updated_at
    }
""",

    "04_logical_architecture": """flowchart TD
    subgraph Client_Layer ["Client Tier (Dual Frontends)"]
        iOS["Farmer Native Client\n(SwiftUI / MapKit)"]
        Web["Agronomist & Admin Portal\n(React 19 / Vite / MapLibre GL)"]
    end

    subgraph Edge_Layer ["Edge Sensing Tier"]
        ESP32["ESP32 Hardware Node\n(Moisture, Temp, Battery)"]
        SerialBridge["Python Serial Bridge\n(USB-C Serial Gateway)"]
    end

    subgraph Backend_Layer ["AgriVision Backend Platform"]
        Gateway["FastAPI API Gateway\n(Auth, Fields, Satellite, Chat, Sensors)"]
        MQTT_Broker["Mosquitto MQTT Broker\n(Port 1883)"]
        MQTT_Worker["Async MQTT Ingestion Worker\n(Batch Deduplication & Conflict Upsert)"]
        Scheduler["Async Scheduler Engine\n(ai_reasoning_loop, external_data_loop)"]
        Aggregator["Telemetry Rollup Worker\n(Hourly/Daily Aggregates & Purge)"]
    end

    subgraph Data_Layer ["Data Tier (PostgreSQL + TimescaleDB)"]
        PG_DB[("PostgreSQL 16 + PostGIS\nRelational Entities & Spatial Polygons")]
        TS_DB[("TimescaleDB Engine\nsensor_readings Hypertables")]
        DiskStorage[("Private Local Storage\nSanitized Photos & Raster Tiles")]
    end

    subgraph Cloud_Layer ["External Cloud & AI Services"]
        FirebaseAuth["Firebase Auth\nJWT Verification"]
        AgroCloud["AgroMonitoring REST API\nSentinel-2 Satellite & Weather"]
        GeminiCloud["Google Gemini 2.5 Flash\nMultimodal Diagnostics & Chat"]
        VertexRAG["Vertex AI Knowledge Base\nPunjab Extension Documents"]
    end

    iOS -- "HTTPS REST (Bearer JWT)" --> Gateway
    Web -- "HTTPS REST (Bearer JWT)" --> Gateway
    iOS -- "Auth Signs In" --> FirebaseAuth
    Web -- "Auth Signs In" --> FirebaseAuth

    ESP32 -- "Serial Telemetry" --> SerialBridge
    SerialBridge -- "MQTT Publish" --> MQTT_Broker
    ESP32 -. "Direct WiFi MQTT" .-> MQTT_Broker
    MQTT_Broker --> MQTT_Worker
    MQTT_Worker -- "Conflict Upsert" --> TS_DB
    Aggregator -- "Hourly Rollup" --> TS_DB

    Gateway --> PG_DB
    Gateway --> TS_DB
    Gateway --> DiskStorage
    Gateway --> FirebaseAuth

    Scheduler -- "Polygon & Weather Sync" --> AgroCloud
    Scheduler -- "Generate Insights" --> GeminiCloud
    Gateway -- "Vision Diagnostics" --> GeminiCloud
    GeminiCloud -- "Grounding" --> VertexRAG
""",

    "05_deployment_architecture": """flowchart TD
    subgraph External_Clients ["Client Access"]
        iOS_Sim["Xcode iOS Simulator / Physical iPhone"]
        Browser["Desktop Web Browsers (Chrome / Safari)"]
    end

    subgraph Host_Environment ["Host Machine (macOS / Linux Engine)"]
        subgraph Ingress ["Web Presentation"]
            Vite_App["Web Application (Vite / Nginx)\nPort 5173 / 80"]
        end

        subgraph Docker_Compose ["Docker Network (agrivision-net)"]
            FastAPI_App["FastAPI Backend Container\nPython 3.12 / Uvicorn\nPort 8000"]
            Postgres_App["Database Container\nPostgres 16 + PostGIS + TimescaleDB\nPort 5432"]
            Mosquitto_App["Mosquitto MQTT Container\nEclipse Mosquitto 2.0\nPort 1883"]
        end

        subgraph Volumes ["Docker Named Volumes"]
            vol_pg[("pgdata\nRelational DB & Hypertables")]
            vol_media[("mediadata\nSanitized Crop Photos & Tiles")]
            vol_mqtt[("mosquittodata\nMQTT Buffer Persistence")]
        end

        Bridge_App["Python Serial-to-MQTT Gateway\nReads /dev/cu.usbserial"]
    end

    subgraph Hardware_Edge ["Physical Sensor Hardware"]
        ESP32_Device["ESP32 Dev Module (Analog Pin 5, Pin 6)"]
    end

    subgraph Cloud_APIs ["External Internet Services"]
        Firebase_Svc["Firebase Authentication"]
        Agro_Svc["AgroMonitoring REST API"]
        Google_AI["Google Gemini 2.5 Flash API"]
    end

    Browser -- "HTTP 5173" --> Vite_App
    Browser -- "REST API 8000" --> FastAPI_App
    iOS_Sim -- "REST API 8000" --> FastAPI_App

    ESP32_Device -- "USB-C Serial" --> Bridge_App
    Bridge_App -- "TCP 1883" --> Mosquitto_App
    ESP32_Device -. "Direct WiFi 1883" .-> Mosquitto_App

    FastAPI_App -- "Internal 5432" --> Postgres_App
    FastAPI_App -- "Internal 1883" --> Mosquitto_App

    Postgres_App --- vol_pg
    FastAPI_App --- vol_media
    Mosquitto_App --- vol_mqtt

    FastAPI_App -- "HTTPS 443" --> Cloud_APIs
""",

    "06_seq_field_creation": """sequenceDiagram
    autonumber
    participant Farmer as Farmer iOS Client
    participant API as FastAPI Backend
    participant DB as PostgreSQL PostGIS
    participant Worker as Background Task Worker
    participant AgroAPI as AgroMonitoring Cloud

    Farmer->>API: POST /api/fields with GeoJSON Polygon
    API->>API: Validate polygon closure and compute area in hectares
    API->>DB: INSERT into fields (boundary ST_MakePolygon, area_ha)
    DB-->>API: Field record created (Field ID)
    API->>Worker: Enqueue background satellite sync (Field ID)
    API-->>Farmer: Return 201 Created (Field Response)

    Worker->>AgroAPI: POST /polygons with GeoJSON coordinates
    AgroAPI-->>Worker: Return permanent agromonitoring_polygon_id
    Worker->>DB: UPDATE fields SET agromonitoring_polygon_id, agro_status active
    Worker->>AgroAPI: GET satellite scenes weather and NDVI for Polygon ID
    AgroAPI-->>Worker: Return multi-spectral statistics and imagery URLs
    Worker->>DB: INSERT into satellite_scenes and field_observations
    Worker-->>Worker: Satellite sync complete and initial NDVI cached
""",

    "07_seq_iot_telemetry": """sequenceDiagram
    autonumber
    participant Node as Physical ESP32 Node
    participant Broker as Mosquitto MQTT Broker
    participant Consumer as MQTT Ingestion Consumer
    participant Timescale as TimescaleDB Hypertable
    participant Aggregator as Hourly Aggregator Worker

    loop Every 30 Seconds
        Node->>Node: Read moisture ADC Pin 5 and temperature DS18B20 Pin 6
        Node->>Node: Sample battery voltage percentage (0 to 100)
        Node->>Broker: Publish JSON to agrivision/sensors/DEVICE_ID
        Broker->>Consumer: Deliver telemetry payload
        Consumer->>Consumer: Validate metrics and filter empty probe payloads
        Consumer->>Timescale: Batch upsert ON CONFLICT (time, sensor_id) DO UPDATE
        Timescale-->>Consumer: Confirmed batch insert
    end

    loop Every Hour (Cron)
        Aggregator->>Timescale: Calculate MIN MAX AVG for previous hour bucket
        Timescale-->>Aggregator: Aggregate metrics
        Aggregator->>Timescale: Upsert into sensor_readings_hourly
        Aggregator->>Timescale: Purge raw readings older than 14 days
    end
""",

    "08_seq_ai_reasoning_hitl": """sequenceDiagram
    autonumber
    participant Scheduler as AI Reasoning Scheduler
    participant DB as PostgreSQL Database
    participant AIAdvisor as AI Advisor Service
    participant Gemini as Google Gemini 2.5 Flash
    participant Agronomist as Agronomist Web Portal
    participant Farmer as Farmer iOS Client

    Scheduler->>DB: Query active fields with sensor trends and NDVI
    DB-->>Scheduler: Return Field Context Snapshot
    Scheduler->>AIAdvisor: run_ai_by_field_id(Field ID, Context Snapshot)
    AIAdvisor->>Gemini: Submit agronomic prompt with weather and soil data
    Gemini-->>AIAdvisor: Return structured recommendation JSON

    AIAdvisor->>AIAdvisor: Inspect advice for chemical and dosage keywords
    alt Chemical or Dosage Detected (High Risk)
        AIAdvisor->>DB: INSERT field_recommendations with expert_status pending_review
        DB-->>AIAdvisor: Recommendation queued
        Agronomist->>DB: GET /api/recommendations/pending-review
        DB-->>Agronomist: Return pending recommendations with telemetry
        Agronomist->>Agronomist: Inspect soil moisture, crop stage, and dosage
        Agronomist->>DB: POST /api/recommendations/{id}/review (Approved with notes)
        DB->>Farmer: Send Push Notification (Critical Action Approved)
    else Routine Cultural Advice (Low Risk)
        AIAdvisor->>DB: INSERT field_recommendations with expert_status approved
        DB->>Farmer: Send Standard Advice Bulletin on Dashboard
    end
""",

    "09_seq_multimodal_chat": """sequenceDiagram
    autonumber
    participant Farmer as Farmer iOS Client
    participant API as FastAPI Chat Router
    participant Storage as Media Storage Service
    participant RAG as Vertex AI Knowledge Base
    participant Gemini as Google Gemini 2.5 Flash
    participant DB as PostgreSQL Database

    Farmer->>Farmer: Capture high-resolution photo of diseased leaf
    Farmer->>API: POST /api/chat/message with image bytes and prompt
    API->>API: Strip EXIF metadata and resize image to maximum 1600px
    API->>Storage: Save sanitized JPEG to disk with SHA256 key
    Storage-->>API: Confirm file saved

    API->>RAG: Query localized pathology compendiums for leaf symptoms
    RAG-->>API: Return grounded treatment guidelines
    API->>Gemini: Dispatch Image bytes User Prompt and Grounding Docs
    Gemini-->>API: Return diagnosis (Septoria Leaf Blight) and cultural treatment

    API->>DB: INSERT into ai_chat_messages and chat_attachments
    API-->>Farmer: Return 200 OK with diagnostic markdown response
    Farmer->>Farmer: Render assistant reply with highlighted safety notices
""",

    "10_seq_staff_invitation": """sequenceDiagram
    autonumber
    participant Admin as Admin Web Portal
    participant API as FastAPI Auth Router
    participant DB as PostgreSQL Database
    participant EmailSvc as SMTP Email Service
    participant Agronomist as New Agronomist User
    participant Firebase as Firebase Auth Provider

    Admin->>API: POST /api/auth/invitations (email, role agronomist)
    API->>API: Normalize email to lowercase and generate secure token
    API->>DB: INSERT into invitations (expires in 7 days, status pending)
    DB-->>API: Confirm Invitation persisted
    API->>EmailSvc: Send invitation link with token
    EmailSvc-->>Agronomist: Deliver invitation email

    Agronomist->>Firebase: Sign in with Google or Email
    Firebase-->>Agronomist: Issue JWT ID Token
    Agronomist->>API: POST /api/auth/invitations/accept with token and Bearer JWT
    API->>DB: Match invitation by token and case-insensitive email
    DB-->>API: Valid invitation confirmed
    API->>DB: UPDATE users SET role agronomist WHERE firebase_uid matches
    API->>DB: UPDATE invitations SET status accepted
    API-->>Agronomist: Return 200 OK with upgraded Agronomist Profile
""",

    "11_class_ios_client": """classDiagram
    class FieldSessionStore {
        +List~Field~ fields
        +UUID activeFieldId
        +Field activeField
        +Boolean isLoading
        +String errorMessage
        +bootstrapSession() async
        +selectField(UUID id)
        +addField(Field field)
        +updateActiveField(Field field)
    }

    class DashboardViewModel {
        +Field activeField
        +List~SensorReading~ recentReadings
        +List~FieldRecommendation~ recommendations
        +Boolean isRefreshing
        +fetchDashboardData() async
        +refreshRecommendations() async
        +recordRecommendationOutcome(UUID id, String outcome) async
    }

    class AIChatViewModel {
        +UUID fieldId
        +List~ChatMessage~ messages
        +Data selectedImageData
        +Boolean isProcessing
        +sendMessage(String text) async
        +attachImage(Data data)
        +removeImage()
    }

    class FieldSelectionViewModel {
        +List~CLLocationCoordinate2D~ boundaryPoints
        +String fieldName
        +String selectedCropType
        +Date plantationDate
        +addPoint(CLLocationCoordinate2D coord)
        +clearPoints()
        +saveField() async
    }

    class AgriDataRepository {
        <<Interface>>
        +fetchFields() async List~Field~
        +fetchDashboard(UUID fieldId) async DashboardData
        +sendChatMessage(UUID fieldId, String text, Data image) async ChatResponse
        +createField(FieldPayload payload) async Field
    }

    class APIClient {
        +performRequest~T~(Endpoint endpoint) async T
        +uploadMultipart~T~(Endpoint endpoint, Data fileData) async T
    }

    DashboardViewModel --> FieldSessionStore
    DashboardViewModel --> AgriDataRepository
    AIChatViewModel --> AgriDataRepository
    FieldSelectionViewModel --> AgriDataRepository
    AgriDataRepository --> APIClient
""",

    "12_class_web_app": """classDiagram
    class HttpClient {
        +get~T~(String url, RequestOptions options) Promise~T~
        +post~T~(String url, Object body, RequestOptions options) Promise~T~
        +patch~T~(String url, Object body, RequestOptions options) Promise~T~
        +delete~T~(String url, RequestOptions options) Promise~T~
    }

    class AdvisoryService {
        +getRecommendations(UUID fieldId, String status) Promise~RecommendationList~
        +reviewRecommendation(UUID id, ReviewPayload payload) Promise~Recommendation~
        +getChatTranscript(UUID fieldId) Promise~MessageList~
        +injectGuidance(UUID fieldId, String guidance) Promise~GuidanceResponse~
    }

    class SensorService {
        +getSensors() Promise~SensorList~
        +getSensorReadings(UUID sensorId, String granularity) Promise~ReadingList~
        +pairSensor(String deviceId, UUID fieldId) Promise~Sensor~
        +unpairSensor(UUID sensorId) Promise~void~
        +verifySensor(String deviceId) Promise~VerificationResult~
    }

    class FieldService {
        +getFields() Promise~FieldList~
        +getField(UUID id) Promise~FieldDetail~
        +createField(FieldCreatePayload payload) Promise~Field~
        +getSatelliteTilesUrl(UUID fieldId, String layer) String
    }

    class useFleetStore {
        +List~Sensor~ sensors
        +Boolean isLoading
        +String error
        +fetchSensors() Promise~void~
        +pairSensor(String deviceId) Promise~void~
    }

    class useAdvisoryStore {
        +List~Recommendation~ pendingReviewList
        +Boolean isSubmitting
        +fetchPendingRecommendations() Promise~void~
        +submitReview(UUID id, String action, String notes) Promise~void~
    }

    AdvisoryService --> HttpClient
    SensorService --> HttpClient
    FieldService --> HttpClient
    useFleetStore --> SensorService
    useAdvisoryStore --> AdvisoryService
""",

    "13_class_backend": """classDiagram
    direction TB

    class FieldsRouter {
        +create_field(payload, db, user)
        +get_fields(db, user)
        +get_field_detail(id, db, user)
    }

    class SatelliteRouter {
        +get_satellite_scenes(id, db, user)
        +get_satellite_tile(id, layer, z, x, y)
    }

    class RecommendationsRouter {
        +get_field_recommendations(id, db)
        +review_recommendation(id, data, db)
    }

    class SensorsRouter {
        +get_sensors(db, user)
        +pair_sensor(data, db, user)
        +get_sensor_readings(id, gran, db)
    }

    class AgromonitoringService {
        +create_polygon(id, geo)
        +fetch_satellite_scene(polygon_id)
        +fetch_weather_forecast(polygon_id)
    }

    class AIAdvisorService {
        +run_ai_by_field_id(id, db)
        +chat_with_advisor(id, text, img, db)
    }

    class MQTTService {
        +start_broker_listener()
        +process_telemetry_packet(topic, data)
    }

    class SchedulerService {
        +start_scheduler()
        +ai_reasoning_loop()
        +rollup_hourly_aggregates()
    }

    class FieldEntity {
        +UUID id
        +String name
        +Geometry boundary
        +Float area_ha
    }

    class SensorEntity {
        +UUID id
        +String device_id
        +Float battery_level
        +DateTime last_seen
    }

    class RecommendationEntity {
        +UUID id
        +String category
        +String priority
        +Text advice
        +String expert_status
    }

    FieldsRouter ..> AgromonitoringService : delegates
    SatelliteRouter ..> AgromonitoringService : delegates
    RecommendationsRouter ..> AIAdvisorService : delegates
    SensorsRouter ..> MQTTService : delegates

    SchedulerService ..> AIAdvisorService : invokes
    SchedulerService ..> AgromonitoringService : invokes

    AgromonitoringService ..> FieldEntity : updates
    AIAdvisorService ..> RecommendationEntity : creates
    MQTTService ..> SensorEntity : updates
"""
}

print(f"Rendering {len(diagrams)} diagrams to PNG and SVG...")

for name, code in diagrams.items():
    code_clean = code.strip()
    encoded = base64.b64encode(code_clean.encode("utf-8")).decode("ascii")

    # 1. Fetch PNG
    png_url = f"https://mermaid.ink/img/{encoded}"
    png_path = os.path.join(out_dir, f"{name}.png")
    try:
        req = urllib.request.Request(png_url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=12) as resp:
            with open(png_path, "wb") as f:
                f.write(resp.read())
        print(f"  [PNG] OK -> {name}.png ({os.path.getsize(png_path)} bytes)")
    except Exception as e:
        print(f"  [PNG] FAILED -> {name}: {e}")

    # 2. Fetch SVG
    svg_url = f"https://mermaid.ink/svg/{encoded}"
    svg_path = os.path.join(out_dir, f"{name}.svg")
    try:
        req = urllib.request.Request(svg_url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=12) as resp:
            with open(svg_path, "wb") as f:
                f.write(resp.read())
        print(f"  [SVG] OK -> {name}.svg ({os.path.getsize(svg_path)} bytes)")
    except Exception as e:
        print(f"  [SVG] FAILED -> {name}: {e}")

    time.sleep(0.3)

print("Finished rendering all diagrams!")
