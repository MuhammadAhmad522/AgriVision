#!/usr/bin/env python3
"""
build_full_srs.py
Generates the complete, verified, codebase-adherent AgriVision Software Requirements Specification (SRS)
in both a unified master Markdown file (AgriVision_SRS.md) and an interactive, styled HTML file (AgriVision_SRS.html).

Adheres strictly to the 11 sections requested by the user:
1. Scope of the Project
2. Functional Requirements & Non Functional requirements
3. Use Case Diagram
4. Adopted Methodology
5. Work Plan (Use MS Project to create Schedule/Work Plan)
6. Entity Relationship Diagram (ERD)
7. Architecture Design Diagram
8. Sequence Diagrams & Usage Scenarios
9. Class Diagram
10. Database Design
11. Interface Design
"""

import os

base_dir = "/Users/ahmad/AgriVision/Docs/srs"
md_path = os.path.join(base_dir, "AgriVision_SRS.md")
html_path = os.path.join(base_dir, "AgriVision_SRS.html")

content = """# AgriVision Software Requirements Specification (SRS)

# 1. Scope of the Project

## 1.1 Project Overview
AgriVision is an enterprise-grade, multi-tenant precision agriculture and agronomy intelligence platform. The core objective of the system is to continuously monitor, evaluate, and optimize crop health across the farming lifecycle. AgriVision achieves this by synthesizing tri-source environmental telemetry—macro-level multi-spectral satellite imagery, micro-level physical IoT ground sensors, and user-submitted multi-modal visual observations—coupled with advanced generative AI reasoning and Human-in-the-Loop (HITL) agronomist validation.

By bridging complex geospatial remote sensing, low-power edge computing, and conversational artificial intelligence, AgriVision translates raw agronomic indicators into actionable, safety-guarded guidance. This empowers farmers to maximize crop yields, conserve water and soil nutrients, and mitigate biological and climatological risks with scientific precision.

## 1.2 Target Audience & Stakeholders
The platform strictly implements access control across four authenticated roles and agricultural stakeholders:
1. **Farmers (`mobile_user`):** Field owners and agricultural workers who utilize the native iOS mobile application to map field boundaries, inspect live sensor telemetry, track satellite vegetative health, receive verified recommendations, and converse directly with the AI Agronomist for immediate crop diagnostics.
2. **Agronomists & Crop Specialists (`agronomist`):** Certified agricultural scientists who utilize the Web Application portal to monitor regional field portfolios, review and approve high-risk AI-generated recommendations (pesticide/chemical dosages), inject authoritative guidance to steer AI conversational responses, and analyze multi-spectral satellite rasters.
3. **System Administrators (`admin`):** Platform managers who oversee system health, configure dynamic AI model hyperparameters and reasoning prompts, manage hardware sensor provisioning, monitor ingestion pipelines, and administer multi-tenant staff invitations and access policies.
4. **Agricultural Enterprises & Extension Services:** Cooperatives seeking centralized visibility over distributed farm acreage, sensor fleet telemetry, and automated compliance audits.

## 1.3 In-Scope Functionalities
The system comprises four fully developed and functional subsystems:

### 1. Multi-Spectral Satellite Remote Sensing & GIS Engine
* **Vector Boundary Georeferencing:** Interactive drawing and validation of field boundaries using PostGIS polygons, enforcing vertex topological integrity and surface area limits.
* **Automated Satellite Ingestion:** Automated synchronization with AgroMonitoring and Sentinel-2 satellite constellations to retrieve cloud-masked surface imagery, NDVI vegetation indices, soil moisture profiles, UV indices, and 5-day weather forecasts.
* **Multi-Layer Spectral Tile Rendering:** High-resolution map tile generation supporting 8 specialized spectral indices: NDVI (Vegetation Health), NDWI (Water Stress), EVI (Enhanced Vegetation), Truecolor (RGB), Falsecolor (Infrared), EVI2 (Two-Band Enhanced), NRI (Nitrogen Reflectance), and DSWI (Disease-Water Stress).

### 2. Physical IoT Sensor Array & Telemetry Ingestion Pipeline
* **ESP32 Edge Sensor Nodes:** Physical microcontrollers deployed in fields measuring soil moisture (calibrated 12-bit ADC), soil temperature (Dallas DS18B20 1-Wire bus), humidity, pH, electrical conductivity (EC), and nitrogen-phosphorus-potassium (NPK) nutrient levels.
* **Resilient Non-Blocking Edge Firmware:** FreeRTOS-based firmware featuring a non-blocking WiFi reconnect state machine, sensor fault detection (disconnect/NAN suppression), battery level reporting (0–100%), and authenticated MQTT packet transmission.
* **High-Throughput Time-Series Ingestion:** Mosquitto MQTT broker integrated with an asynchronous FastAPI consumer pipeline writing to a PostgreSQL / TimescaleDB hypertable with primary key conflict handling (`(time, sensor_id)`).
* **Automated Time-Series Rollup:** Scheduled cron workers that continuously aggregate raw readings into hourly and daily statistical buckets (Min, Max, Avg, Count) to power responsive analytics dashboards while managing data retention.

### 3. Generative AI Advisory Engine & Multi-Modal Diagnostics
* **Multi-Modal Crop Disease Diagnostics:** Native camera integration allowing farmers to submit high-resolution crop photos. The backend enforces privacy-preserving EXIF stripping, image resizing, and multi-modal visual inspection via Google Gemini 2.5 Flash.
* **Retrieval-Augmented Generation (RAG):** Contextual grounding of AI queries against localized agricultural knowledge repositories (Punjab Agricultural Extension, disease pathology databases, and crop-specific management guides).
* **Autonomous AI Reasoning Loop (`ai_reasoning_loop`):** Background scheduler that continuously evaluates multi-source field context (sensor trends, weather forecasts, satellite anomalies) against agronomic rule matrices to synthesize field-specific recommendations without requiring manual user initiation.
* **Season Memory Narrative:** Rolling 1,200-character crop season memory that continuously summarizes key lifecycle milestones, applied treatments, and sensor stresses to maintain persistent multi-month LLM reasoning context without token exhaustion.

### 4. Human-in-the-Loop (HITL) Safety Guardrails & Expert Steering
* **Pesticide & Chemical Dosage Interception:** Rule-based and classifier-driven safety guardrails that detect chemical recommendations, dosage instructions, and high-risk interventions, automatically placing them in a `pending_review` state.
* **Expert Review Queue:** Dedicated Web Application dashboard enabling Agronomists to inspect context snapshots, approve, reject, or annotate recommendations with expert feedback before they are published to farmers.
* **AI Guidance Injection:** Mechanism for Agronomists to inject field-specific steering instructions into AI conversation threads, guiding future responses for specific farms.

### 5. Multi-Client User Experience (Mobile & Web)
* **Native iOS Mobile App (SwiftUI & Combine):** Offline-tolerant architecture (MVVM-C), real-time field telemetry cards, interactive MapKit boundary editor, AI chat interface, push notification handling, and device pairing workflows.
* **Web Application Portal (React 19 & TypeScript):** Responsive desktop interface featuring MapLibre GL GIS visualization with opacity controls, IoT hardware provisioning and battery health fleet overview, advisory review queue, and team invitation management.
* **Multi-Tenant Authentication & RBAC:** Cryptographic JWT validation via Firebase Authentication, case-insensitive email invitation acceptance, and dynamic role enforcement (`admin`, `agronomist`, `mobile_user`).

## 1.4 Out of Scope
To maintain a clearly defined operational scope for the platform, the following capabilities are explicitly designated as out of scope:
1. **Automated Physical Actuation:** The platform generates prescriptive irrigation and fertilization recommendations, but does not directly control physical motor actuators, solenoid water valves, or autonomous field equipment.
2. **Autonomous Drone (UAV) Video Feeds:** Ingestion and real-time processing of live aerial drone video streams are reserved for future architectural releases.
3. **Financial Banking & Commercial Transactions:** The system does not process direct payments, grain trading, or commercial fertilizer purchasing transactions.
4. **Offline AI Model Execution:** All generative AI inference is performed in secure cloud infrastructure; offline on-device LLM inference is out of scope due to mobile hardware constraints.

---

# 2. Functional Requirements & Non Functional requirements

## 2.1 Functional Requirements

The functional requirements define the explicit capabilities, business rules, and services provided by the AgriVision platform, organized by architectural domain.

### Module 1: User Identity, Multi-Tenancy & Access Control
* **FR-1 (Authentication & Session Bootstrap):** 
  * The system must authenticate users via Firebase Authentication using email/password or Google OAuth 2.0.
  * Upon initial app launch, the client must submit the Firebase Bearer token to `/api/session/bootstrap` to resolve the user profile, active fields, sensor inventory, and operational limits in a single round-trip.
* **FR-2 (Role-Based Access Control - RBAC):** 
  * The system must strictly enforce three user roles:
    * `mobile_user` (Farmer): Full management of owned fields, sensors, and direct AI chat.
    * `agronomist` (Expert Staff): Read-only access to all fields, satellite rasters, and sensor rollups across the enterprise; exclusive write access to review, approve, or reject high-risk AI recommendations; authority to inject AI steering guidance.
    * `admin` (System Owner): Full unconstrained access across all tenant resources, user provisioning, dynamic AI configuration, and system audit logs.
* **FR-3 (Multi-Tenant Team Invitations):** 
  * Admins and Agronomists must be able to invite new team members via email with a designated role (`agronomist` or `mobile_user`).
  * Email matching must be case-insensitive (`func.lower(Invitation.email) == email.lower()`).
  * If an existing user with role `mobile_user` accepts an agronomist invitation, the system must automatically elevate their role to `agronomist`.
  * Invitations must expire after 7 days and become invalid once accepted.

### Module 2: Field Boundary & Geospatial Management
* **FR-4 (Field Creation & PostGIS Georeferencing):** 
  * Farmers must be able to define field boundaries by supplying an ordered list of at least 3 GPS coordinates forming a closed polygon.
  * The backend must validate polygon topology using PostGIS (`ST_MakePolygon`, `ST_IsValid`), compute surface area in hectares (`area_ha`), and calculate the geographical centroid.
* **FR-5 (AgroMonitoring Polygon Synchronization):** 
  * Upon field creation, the system must asynchronously register the field boundary with the AgroMonitoring REST API to obtain a permanent `agromonitoring_polygon_id`.
  * If the external API times out, the system must persist the local polygon, mark `agro_status="pending"`, and retry via background scheduler with exponential backoff.
  * When a field is deleted, the system must delete the remote polygon. If the upstream provider returns HTTP 404, the system must treat deletion as an idempotent success.
* **FR-6 (Multi-Spectral Satellite Raster Tile Rendering):** 
  * The system must serve high-resolution map tiles (`/api/fields/{id}/satellite/latest/tile/{layer}/{z}/{x}/{y}`) across 8 spectral layers:
    1. `ndvi` (Normalized Difference Vegetation Index)
    2. `ndwi` (Normalized Difference Water Index)
    3. `evi` (Enhanced Vegetation Index)
    4. `truecolor` (Natural RGB Surface Imagery)
    5. `falsecolor` (Infrared Vegetation Composition)
    6. `evi2` (Two-Band Enhanced Vegetation Index)
    7. `nri` (Nitrogen Reflectance Index)
    8. `dswi` (Disease-Water Stress Index)
  * The system must cache satellite tile rasters locally and securely authenticate tile requests from the Web GIS map viewer using Bearer tokens.

### Module 3: IoT Sensor Fleet Management & Telemetry Ingestion
* **FR-7 (Hardware Provisioning & Pairing):** 
  * Farmers and Admins must be able to pair physical ESP32 sensor nodes by specifying a unique `device_id` and associating it with a field.
  * The Web App and iOS App must support device verification, unpairing, and field reassignment.
* **FR-8 (Real-Time MQTT Telemetry Ingestion):** 
  * The backend must maintain a persistent MQTT consumer subscribed to topic `agrivision/sensors/+`.
  * Telemetry payloads must support soil temperature, soil moisture, humidity, pH, electrical conductivity (EC), and NPK (nitrogen, phosphorus, potassium).
  * The ingestion pipeline must handle duplicate timestamp collisions via PostgreSQL `ON CONFLICT (time, sensor_id) DO UPDATE`.
  * If a physical sensor disconnects or emits `NAN` across all metrics, the pipeline must update `sensor.last_seen` while suppressing blank rows in the database.
* **FR-9 (Battery Monitoring & Time-Series Rollup):** 
  * Sensor nodes must transmit battery telemetry (`battery` or `battery_level` in the 0–100% range). The system must update `sensor.battery_level` and raise low-battery warnings when level falls below 20%.
  * Scheduled background workers must compress raw time-series data into hourly and daily statistical rollups (`sensor_readings_hourly`: Min, Max, Avg, Count).
  * Raw sensor readings must be purged after 14 days, while hourly rollups are retained indefinitely for multi-year trend analysis.

### Module 4: Generative AI Advisory & Crop Health Diagnostics
* **FR-10 (Multi-Modal Pathology Diagnostic Chat):** 
  * Farmers must be able to capture crop photos via iOS camera and submit diagnostic queries to the AI Agronomist.
  * The backend must strip EXIF metadata, resize images to a maximum dimension of 1600px, and perform multi-modal visual inference using Google Gemini 2.5 Flash.
  * Responses must be generated synchronously within conversational latency constraints (<3 seconds).
* **FR-11 (Retrieval-Augmented Generation Grounding):** 
  * AI inference queries must be dynamically augmented with relevant excerpts from verified agricultural research documents (Punjab Agricultural Extension, crop pathology compendiums, irrigation guides).
* **FR-12 (Autonomous AI Reasoning Loop):** 
  * An asynchronous scheduler (`ai_reasoning_loop`) must evaluate active fields every 5 minutes against current sensor trends, satellite vegetative health, and 5-day weather forecasts.
  * The engine must compute a holistic `latest_health_score` (0–100), health category label (e.g., "Optimal", "Monitor Water Deficit"), and written rationale.
  * If the primary AI provider is unavailable, the system must deterministically generate fallback recommendations derived directly from sensor threshold matrices.
* **FR-13 (Crop Season Memory Narrative):** 
  * The system must maintain a rolling 1,200-character narrative (`field_season_memory`) summarizing key lifecycle events, applied treatments, and stress episodes to provide persistent context for seasonal evaluations.

### Module 5: Human-in-the-Loop (HITL) Agronomist Review & Steering
* **FR-14 (Safety Guardrails & Chemical Dosage Interception):** 
  * The AI reasoning engine must inspect all generated recommendations for chemical interventions, pesticide active ingredients, and dosage instructions.
  * Any recommendation containing regulated substances must be flagged as `high_risk` and marked `expert_status="pending_review"`.
  * Recommendations in `pending_review` must remain invisible to farmers until formally approved by an agronomist.
* **FR-15 (Expert Review & Approval Workflow):** 
  * Agronomists must review queued recommendations via the Web App `AIAdvisoryView`, inspecting the sensor and satellite evidence snapshot.
  * Agronomists may approve or reject recommendations, appending clinical review notes.
  * The system must record `reviewed_by_id` and `reviewed_at` to establish a complete audit trail.
* **FR-16 (Agronomist AI Guidance Steering):** 
  * Agronomists must have the capability to inject authoritative steering guidance into a field's AI conversation thread, dynamically instructing the AI model on treatment constraints for subsequent farmer interactions.

---

## 2.2 Non-Functional Requirements

The non-functional requirements govern the performance, scalability, security, and operational reliability of the platform.

### NFR-1: Performance & Latency
* **API Latency:** 95% of standard REST API requests (field fetching, telemetry queries) must return in under 200 milliseconds.
* **AI Conversational Turnaround:** Multi-modal diagnostic responses from Gemini 2.5 Flash must complete in under 3.5 seconds.
* **Tile Rendering:** Cached satellite raster map tiles must be served in under 150 milliseconds per tile request.

### NFR-2: Throughput & Ingestion Concurrency
* The MQTT ingestion worker must support at least 200 concurrent physical sensor nodes transmitting readings every 5 seconds (40 messages/second) with zero message loss.
* Ingestion pipelines must utilize asynchronous batch buffering to decouple network ingestion from PostgreSQL disk commits.

### NFR-3: Reliability & Fault Tolerance
* **System Availability:** The backend services must target 99.9% uptime during operational agricultural hours.
* **Graceful Degradation:** Failure of third-party satellite or AI cloud APIs must never crash core services or block user field creation. Deterministic rule-based fallbacks must guarantee uninterrupted advice generation.
* **Edge Resilience:** ESP32 firmware must utilize a non-blocking state machine with exponential backoff (1s to 60s) during WiFi disconnection, preventing hardware watchdog panics and starvation of background tasks.

### NFR-4: Data Integrity & Storage
* All geographical boundaries must be validated and stored as PostGIS 2D geometries utilizing SRID 4326 (WGS 84).
* Sensor telemetry must be recorded in TimescaleDB hypertables partitioned by time, ensuring efficient queries across millions of historic records.
* Database foreign keys and cascading delete rules must preserve data integrity across field deletion and sensor unpairing.

### NFR-5: Security & Privacy
* **Transport Encryption:** All communications across iOS, Web, and Backend must enforce TLS 1.3 encryption.
* **Authentication:** Every incoming REST request (except public health checks) must present a cryptographically verified Firebase Bearer token.
* **Image Privacy:** Uploaded crop images must have all EXIF metadata (including camera model, exposure, and embedded GPS coordinates) automatically stripped before storage.
* **Tenant Isolation:** All data access queries must be strictly scoped by tenant ownership or staff role authorization.

### NFR-6: Usability & Mobile Accessibility
* **Field Legibility:** The native iOS application must feature high-contrast UI components and dynamic typography (San Francisco font) to guarantee sunlight readability in outdoor field conditions.
* **Offline Tolerant UX:** The iOS client must maintain a local field session cache, allowing farmers to view cached telemetry and field boundaries even in low-connectivity rural environments.

### NFR-7: Cross-Platform Interoperability
* The backend API must expose standard OpenAPI 3.0 (Swagger) specifications with strictly validated Pydantic models.
* Geodata must strictly adhere to GeoJSON standards (RFC 7946).
* Sensor edge packets must conform to standard JSON over MQTT 3.1.1.

### NFR-8: Maintainability & Testability
* The backend must maintain a comprehensive test suite (pytest) covering security, RBAC, telemetry ingestion, and AI reasoning with 100% test pass rate.
* The Web Application must compile with zero TypeScript errors and zero linter warnings.
* The iOS Application must maintain complete XCTest coverage across all ViewModels, repositories, and state stores.

---

# 3. Use Case Diagram

## 3.1 Actors Description
The AgriVision platform interacts with three human actors, one physical hardware actor, and two external cloud service actors:
* **Farmer (`mobile_user`):** Interacts via the native iOS mobile application to map field boundaries, monitor live telemetry, receive approved agronomic advice, and diagnose crop leaf diseases via AI chat.
* **Agronomist (`agronomist`):** Certified agricultural specialist using the Web Application. Reviews queued high-risk chemical/pesticide recommendations, approves/rejects advice with notes, inspects 8-layer satellite rasters, and steers AI guidance.
* **System Admin (`admin`):** Platform manager who oversees sensor provisioning, configures dynamic AI models, and administers multi-tenant team invitations.
* **IoT Sensor Array (ESP32):** Autonomous edge nodes deployed in fields gathering soil moisture, temperature, NPK, pH, EC, and battery telemetry, transmitting over MQTT.
* **AgroMonitoring API:** External satellite service supplying Sentinel-2 multispectral imagery, vegetation indices (NDVI, NDWI, EVI), weather forecasts, and soil profiles.
* **Google Gemini AI:** Multimodal foundation model processing imagery, user text, and telemetry for pathology diagnosis and proactive advice.

## 3.2 Use Case Diagram Visualization

![System Use Case Diagram](./diagrams/01_use_case_diagram.png)

```mermaid
flowchart TD
    subgraph Actors ["Platform Actors"]
        Farmer["Farmer (iOS Mobile App)"]
        Agronomist["Agronomist (Web Dashboard)"]
        Admin["System Admin (Web Dashboard)"]
        IoT["IoT Sensor Array (ESP32 Edge)"]
        AgroAPI["AgroMonitoring Cloud API"]
        GeminiAI["Google Gemini 2.5 Flash"]
    end

    subgraph Platform ["AgriVision Platform Boundary"]
        subgraph Auth_Mod ["1. Identity & RBAC"]
            UC1["Register & Authenticate"]
            UC2["Invite Staff & Manage Roles"]
        end

        subgraph GIS_Mod ["2. Geospatial & Satellite"]
            UC3["Draw & Validate Field Boundaries"]
            UC4["Sync Satellite Imagery & Weather"]
            UC5["Inspect 8-Layer Spectral Rasters"]
        end

        subgraph IoT_Mod ["3. IoT Hardware & Telemetry"]
            UC6["Pair & Monitor Sensor Fleet"]
            UC7["Transmit Ground Telemetry"]
            UC8["View Live Telemetry Dashboard"]
        end

        subgraph AI_Mod ["4. AI Advisory & Clinical Review"]
            UC9["Chat with AI & Diagnose Diseases"]
            UC10["Autonomous Reasoning & Advice"]
            UC11["Review & Validate Advice (HITL)"]
            UC12["Inject Agronomist Guidance"]
        end
    end

    Farmer --> UC1
    Farmer --> UC3
    Farmer --> UC6
    Farmer --> UC8
    Farmer --> UC9

    Agronomist --> UC1
    Agronomist --> UC5
    Agronomist --> UC8
    Agronomist --> UC11
    Agronomist --> UC12

    Admin --> UC1
    Admin --> UC2
    Admin --> UC6

    IoT --> UC7
    UC7 --> UC8

    UC3 --> AgroAPI
    UC4 --> AgroAPI
    UC5 --> AgroAPI
    UC9 --> GeminiAI
    UC10 --> GeminiAI
```

---

# 4. Adopted Methodology

## 4.1 Agile Scrum Framework
For the engineering and deployment of AgriVision, the **Agile Scrum** methodology was officially adopted. Given the multifaceted nature of the platform—spanning embedded C++ firmware (ESP32), distributed Python/FastAPI microservices, relational and geospatial databases (PostGIS/TimescaleDB), multi-modal generative AI pipelines (Gemini 2.5 Flash), native mobile development (SwiftUI), and a modern web frontend (React 19/Vite)—a rigid, sequential Waterfall model was fundamentally incompatible with the iterative discovery required.

Agile Scrum provided the necessary flexibility, transparency, and cadence across all four development tracks:
* **Time-Boxed Sprints:** Development was organized into 6 bi-weekly to monthly Sprints, each delivering a demonstrable, vertically integrated increment.
* **Concurrent Multi-Track Engineering:** Hardware firmware development, backend cloud API scaffolding, web GIS visualization, and iOS native UI proceeded in parallel streams, minimizing cross-team blocking dependencies.
* **Continuous Integration & Automated Testing:** Every sprint culminated in automated test runs (backend pytest, iOS XCTest, web TypeScript validation, and linter sweeps), ensuring regressions were caught early.
* **Dynamic Feedback & Safety Calibration:** Agile allowed the agricultural domain rules and chemical guardrail thresholds to be calibrated interactively with agronomist feedback without derailing core architecture.

---

# 5. Work Plan (Use MS Project to create Schedule/Work Plan)

The project work plan was developed using a Work Breakdown Structure (WBS) aligned with Microsoft Project scheduling standards, organized across 6 distinct phases and development tracks.

## 5.1 Project Schedule & Gantt Chart

![Project Schedule Gantt Chart](./diagrams/02_gantt_schedule.png)

```mermaid
gantt
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
```

## 5.2 Work Breakdown Structure (WBS) & Task Schedule

| WBS Code | Task Name | Predecessors | Duration | Resource / Assigned Tier |
| :--- | :--- | :--- | :--- | :--- |
| **1.0** | **Project Inception & Architecture** | | **30 days** | Architecture Team |
| 1.1 | Requirements Discovery & SRS Specification | - | 14 days | System Analyst |
| 1.2 | Relational & PostGIS Schema Modeling | 1.1 | 14 days | Database Architect |
| 1.3 | Docker Container Environment Scaffolding | 1.1 | 14 days | DevOps Engineer |
| **2.0** | **Edge Hardware & Telemetry Ingestion** | | **36 days** | Hardware & Backend |
| 2.1 | ESP32 Sensor Drivers (Moisture ADC, Temp DS18B20) | 1.3 | 20 days | Embedded Engineer |
| 2.2 | Non-blocking WiFi & Authenticated MQTT Client | 2.1 | 14 days | Embedded Engineer |
| 2.3 | Mosquitto Broker & FastAPI Ingestion Worker | 2.1 | 16 days | Backend Engineer |
| 2.4 | AgroMonitoring REST Polygon Sync Client | 1.3 | 20 days | Backend Engineer |
| **3.0** | **AI Reasoning & Safety Guardrails** | | **40 days** | AI & Data Engineering |
| 3.1 | Google Gemini 2.5 Flash Multimodal Pipeline | 1.3 | 22 days | AI Engineer |
| 3.2 | Autonomous Scheduler Engine (`ai_reasoning_loop`) | 3.1 | 18 days | Backend Engineer |
| 3.3 | Chemical Safety Guardrails & Expert Review Queue | 3.2 | 14 days | Backend / Domain |
| **4.0** | **Client Application Engineering** | | **45 days** | Frontend & Mobile |
| 4.1 | Native iOS Client (SwiftUI, MapKit, Telemetry Cards) | 2.3 | 30 days | iOS Engineer |
| 4.2 | Web Application Portal (React 19, MapLibre GIS) | 2.4 | 30 days | Frontend Engineer |
| 4.3 | IoT Hardware Fleet & Multi-Tenant Team Views | 4.2 | 16 days | Frontend Engineer |
| **5.0** | **System Audit & Hardening** | | **35 days** | QA & Security |
| 5.1 | Full-System End-to-End Audit & Bug Remediation | 4.1, 4.2 | 20 days | All Engineers |
| 5.2 | Automated Regression Suite (Pytest 183, XCTest 213) | 5.1 | 15 days | QA Engineer |
| **6.0** | **Documentation & Final Delivery** | | **30 days** | Full Team |
| 6.1 | Comprehensive SRS, ERD & Architecture Docs | 5.2 | 15 days | Tech Lead |
| 6.2 | Final Production Deployment & Demonstration | 6.1 | 15 days | Full Team |

---

# 6. Entity Relationship Diagram (ERD)

The AgriVision database architecture combines relational modeling (PostgreSQL) with geospatial extensions (PostGIS) and time-series hypertables (TimescaleDB) to efficiently handle multi-tenant operational records, high-frequency IoT streams, and geospatial polygons.

## 6.1 Core Database ERD

![Core Database ERD](./diagrams/03_database_erd.png)

```mermaid
erDiagram
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
```

---

# 7. Architecture Design Diagram

The AgriVision platform architecture is presented through two complementary perspectives: High-Level Logical Architecture and Containerized Deployment Architecture.

## 7.1 High-Level Logical Architecture

![High-Level Logical Architecture](./diagrams/04_logical_architecture.png)

```mermaid
flowchart TD
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
```

## 7.2 Low-Level Deployment & Container Architecture

![Low-Level Deployment and Container Architecture](./diagrams/05_deployment_architecture.png)

```mermaid
flowchart TD
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
```

---

# 8. Sequence Diagrams & Usage Scenarios

## 8.1 Usage Scenario 1 & Sequence: Field Creation & Satellite Ingestion Flow
* **Primary Actor:** Farmer (`mobile_user`)
* **Pre-condition:** Authenticated on iOS app; GPS signal available.
* **Flow:** Farmer draws polygon vertices on MapKit canvas -> Client calls `POST /api/fields` -> Backend validates geometry via PostGIS, calculates `area_ha` -> Background worker calls AgroMonitoring `/polygons` -> Returns permanent `agromonitoring_polygon_id` -> Caches Sentinel-2 NDVI raster tiles.

![Field Creation and Satellite Ingestion Sequence](./diagrams/06_seq_field_creation.png)

```mermaid
sequenceDiagram
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
```

---

## 8.2 Usage Scenario 2 & Sequence: IoT Telemetry Streaming & Rollup Flow
* **Primary Actor:** Physical ESP32 Sensor Node
* **Pre-condition:** ESP32 powered, non-blocking WiFi connected, paired to field.
* **Flow:** Every 30s samples moisture ADC (Pin 5) and temperature (Pin 6) -> Publishes JSON to `agrivision/sensors/DEVICE_ID` -> Mosquitto delivers to async consumer -> Ingests into `sensor_readings` with `ON CONFLICT (time, sensor_id) DO UPDATE` -> Hourly worker rollups to `sensor_readings_hourly` and purges raw data older than 14 days.

![IoT Sensor Telemetry Streaming and Rollup Sequence](./diagrams/07_seq_iot_telemetry.png)

```mermaid
sequenceDiagram
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
```

---

## 8.3 Usage Scenario 3 & Sequence: AI Reasoning Loop & Human-in-the-Loop (HITL) Review Flow
* **Primary Actors:** Agronomist (`agronomist`), Farmer (`mobile_user`)
* **Pre-condition:** Field has active sensor telemetry and recent NDVI data.
* **Flow:** `ai_reasoning_loop` runs every 5 minutes -> Generates recommendation with Gemini 2.5 Flash -> Guardrails detect chemical active ingredients -> Sets `expert_status="pending_review"` -> Agronomist inspects via Web Portal -> Approves with clinical notes -> System records `reviewed_by_id` and `reviewed_at` -> Pushes verified alert to Farmer.

![AI Reasoning and Human-in-the-Loop Review Sequence](./diagrams/08_seq_ai_reasoning_hitl.png)

```mermaid
sequenceDiagram
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
```

---

## 8.4 Usage Scenario 4 & Sequence: Multi-Modal Pathology Diagnostic Chat Flow
* **Primary Actor:** Farmer (`mobile_user`)
* **Pre-condition:** Leaf shows visible lesion symptoms; camera permission granted.
* **Flow:** Farmer captures photo in iOS chat -> Submits multipart POST `/api/chat/message` -> Backend strips EXIF, resizes to 1600px, computes SHA256 key -> RAG queries Punjab pathology guidelines -> Dispatches image + text to Gemini 2.5 Flash -> Returns diagnosis and cultural treatment in under 3s.

![Multi-Modal Pathology Diagnostic Chat Sequence](./diagrams/09_seq_multimodal_chat.png)

```mermaid
sequenceDiagram
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
```

---

## 8.5 Usage Scenario 5 & Sequence: Multi-Tenant Staff Invitation & Role Elevation Flow
* **Primary Actors:** System Admin (`admin`), Agronomist Candidate
* **Pre-condition:** Admin logged into Web Application; candidate has valid email.
* **Flow:** Admin submits `/api/auth/invitations` -> Case-insensitive email normalized, 7-day token created -> Candidate clicks link, signs in with Firebase -> Submits `/api/auth/invitations/accept` -> Backend upgrades user role to `agronomist`, marks invitation accepted.

![Multi-Tenant Staff Invitation and Role Elevation Sequence](./diagrams/10_seq_staff_invitation.png)

```mermaid
sequenceDiagram
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
```

---

# 9. Class Diagram

The class diagram architecture models the concrete object-oriented design and abstractions implemented across the native iOS client, the web application frontend, and the backend service layer.

## 9.1 Native iOS Client Class Architecture (MVVM-C)

![Native iOS Client Class Diagram](./diagrams/11_class_ios_client.png)

```mermaid
classDiagram
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
```

## 9.2 Web Application Services & State Stores

![Web Application Services and State Stores Class Diagram](./diagrams/12_class_web_app.png)

```mermaid
classDiagram
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
```

## 9.3 Backend Routers, Domain Services & Models

![Backend Routers Domain Services and Models Class Diagram](./diagrams/13_class_backend.png)

```mermaid
classDiagram
    class FieldsRouter {
        +create_field(payload, db, current_user)
        +get_fields(db, current_user)
        +get_field_detail(field_id, db, current_user)
        +delete_field(field_id, db, current_user)
    }

    class SatelliteRouter {
        +get_satellite_scenes(field_id, db, current_user)
        +get_satellite_tile(field_id, layer, z, x, y, db, current_user)
    }

    class RecommendationsRouter {
        +get_field_recommendations(field_id, db, current_user)
        +get_pending_reviews(db, current_user)
        +review_recommendation(rec_id, review_data, db, current_user)
    }

    class SensorsRouter {
        +get_sensors(db, current_user)
        +pair_sensor(pair_data, db, current_user)
        +verify_sensor(device_id, db, current_user)
        +get_sensor_readings(sensor_id, granularity, db, current_user)
    }

    class AgromonitoringService {
        +create_polygon(field_id, geometry)
        +delete_polygon(polygon_id)
        +fetch_satellite_scene(polygon_id)
        +fetch_weather_forecast(polygon_id)
    }

    class AIAdvisorService {
        +run_ai_by_field_id(field_id, db)
        +chat_with_advisor(field_id, text, image_data, db)
        +evaluate_safety_guardrails(recommendation_text)
    }

    class MQTTService {
        +start_broker_listener()
        +process_telemetry_packet(topic, payload)
        +_batch_writer_loop()
    }

    class SchedulerService {
        +start_scheduler()
        +ai_reasoning_loop()
        +external_data_loop()
        +rollup_hourly_aggregates()
    }

    FieldsRouter --> AgromonitoringService
    SatelliteRouter --> AgromonitoringService
    RecommendationsRouter --> AIAdvisorService
    SensorsRouter --> MQTTService
    SchedulerService --> AIAdvisorService
    SchedulerService --> AgromonitoringService
```

---

# 10. Database Design

The AgriVision persistence architecture utilizes PostgreSQL 16 enriched with the PostGIS spatial engine and TimescaleDB extension.

## 10.1 Geospatial Architecture (PostGIS)
* **Spatial Coordinate Reference System:** All spatial boundaries are standardized on EPSG:4326 (WGS 84 latitude/longitude).
* **Column Definition:** `fields.boundary` is typed as `geometry(Geometry, 4326)`, permitting arbitrary polygon boundaries.
* **Spatial Operations:** Boundary validation uses `ST_IsValid()`, polygon assembly uses `ST_MakePolygon(ST_GeomFromText(...))`, and area computation converts the spatial geometry into a planar projection using `ST_Area(geography(boundary)) / 10000.0` to yield hectares (`area_ha`).
* **Spatial Indexing:** A GiST (Generalized Search Tree) spatial index is defined on `fields.boundary` for accelerated bounding-box containment queries.

## 10.2 Time-Series Architecture (TimescaleDB)
* **Hypertable Construction:** The `sensor_readings` table is converted into a TimescaleDB hypertable partitioned by the `time` column into 7-day chunks (`SELECT create_hypertable('sensor_readings', 'time', chunk_time_interval => INTERVAL '7 days', if_not_exists => TRUE);`).
* **Continuous Aggregates:** Hourly rollups compute minimum, maximum, and average values for temperature, moisture, humidity, pH, EC, and NPK nutrients (`sensor_readings_hourly`), speeding up analytical graph rendering by >90%.
* **Data Retention Policies:** Raw 30-second sensor readings are retained for 14 days before automated background worker pruning, while aggregated hourly records are preserved indefinitely.

## 10.3 Complete Data Dictionary

| Table Name | Column Name | Data Type | Nullable | Constraints & Defaults | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`users`** | `id` | UUID | No | PRIMARY KEY, default uuid4 | Internal unique identifier for the user record. |
| | `firebase_uid` | VARCHAR(128) | No | UNIQUE, INDEXED | External Firebase Authentication UID. |
| | `email` | VARCHAR(255) | No | UNIQUE, INDEXED | User primary email address (case-insensitive). |
| | `role` | VARCHAR(32) | No | Default `'mobile_user'` | User role: `'admin'`, `'agronomist'`, or `'mobile_user'`. |
| | `display_name` | VARCHAR(255) | Yes | Nullable | User display name or business title. |
| | `is_active` | BOOLEAN | No | Default `TRUE` | Account active state indicator. |
| | `created_at` | TIMESTAMPTZ | No | Default `now()` | Account creation timestamp. |
| **`invitations`** | `id` | UUID | No | PRIMARY KEY, default uuid4 | Unique invitation identifier. |
| | `email` | VARCHAR(255) | No | INDEXED | Target invitee email address. |
| | `role` | VARCHAR(32) | No | Default `'mobile_user'` | Target role upon acceptance. |
| | `status` | VARCHAR(32) | No | Default `'pending'` | State: `'pending'`, `'accepted'`, `'expired'`. |
| | `token` | VARCHAR(128) | No | UNIQUE, INDEXED | Secure random invitation verification token. |
| | `invited_by_id` | UUID | Yes | FK -> `users.id` | User ID of the administrator issuing the invite. |
| | `expires_at` | TIMESTAMPTZ | No | Default `now() + 7 days` | Invitation expiration cutoff timestamp. |
| **`fields`** | `id` | UUID | No | PRIMARY KEY, default uuid4 | Unique identifier for the field parcel. |
| | `owner_id` | UUID | No | FK -> `users.id`, INDEXED | Foreign key of the field owner. |
| | `name` | VARCHAR(255) | No | Required | Human-readable name of the field. |
| | `crop_type` | VARCHAR(100) | Yes | Nullable | Primary crop planted (e.g., `'Wheat'`). |
| | `plantation_date`| TIMESTAMPTZ | Yes | Nullable | Date crop was sowed. |
| | `boundary` | GEOMETRY(4326)| Yes | GiST INDEXED | PostGIS Polygon geometry of field perimeter. |
| | `area_ha` | FLOAT | Yes | Nullable | Computed surface area in hectares. |
| | `status` | VARCHAR(32) | No | Default `'active'` | Status: `'active'`, `'archived'`. |
| | `agromonitoring_polygon_id` | VARCHAR(64) | Yes | Nullable | External polygon identifier from AgroMonitoring API. |
| | `agro_status` | VARCHAR(32) | No | Default `'pending'` | Satellite sync state: `'pending'`, `'active'`, `'error'`. |
| | `latest_ndvi` | FLOAT | Yes | Nullable | Most recent NDVI vegetation index (range -1.0 to 1.0). |
| | `latest_health_score` | FLOAT | Yes | Nullable | AI holistic crop health score (range 0 to 100). |
| | `latest_health_label` | VARCHAR(64) | Yes | Nullable | Categorical health label (e.g., `'Optimal'`). |
| **`sensors`** | `id` | UUID | No | PRIMARY KEY, default uuid4 | Unique identifier for sensor node. |
| | `owner_id` | UUID | No | FK -> `users.id`, INDEXED | Owner user ID. |
| | `field_id` | UUID | Yes | FK -> `fields.id`, INDEXED | Field the device is currently stationed within. |
| | `device_id` | VARCHAR(64) | No | UNIQUE, INDEXED | Hardware serial/MAC ID (e.g., `'ESP32_01AB'`). |
| | `battery_level`| FLOAT | Yes | Default `100.0` | Reported battery percentage (0.0 to 100.0). |
| | `last_seen` | TIMESTAMPTZ | Yes | Nullable | Timestamp of most recent telemetry transmission. |
| **`sensor_readings`** | `time` | TIMESTAMPTZ | No | COMPOSITE PK, Hypertable | Timestamp of physical reading acquisition. |
| | `sensor_id` | UUID | No | COMPOSITE PK, FK -> `sensors` | Foreign key referencing physical sensor. |
| | `temperature` | FLOAT | Yes | Nullable | Soil/ambient temperature in degrees Celsius. |
| | `moisture` | FLOAT | Yes | Nullable | Volumetric soil moisture percentage (0 to 100%). |
| | `humidity` | FLOAT | Yes | Nullable | Relative atmospheric humidity percentage. |
| | `ph` | FLOAT | Yes | Nullable | Soil acidity/alkalinity measurement (0.0 to 14.0). |
| | `ec` | FLOAT | Yes | Nullable | Electrical conductivity in mS/cm. |
| | `npk_n` | FLOAT | Yes | Nullable | Soil Nitrogen concentration in mg/kg. |
| | `battery_level`| FLOAT | Yes | Nullable | Battery level recorded at reading time. |
| **`sensor_readings_hourly`** | `bucket` | TIMESTAMPTZ | No | COMPOSITE PK, Hourly | Hourly time bucket timestamp. |
| | `sensor_id` | UUID | No | COMPOSITE PK, FK -> `sensors` | Foreign key referencing physical sensor. |
| | `temperature_avg`| FLOAT | Yes | Nullable | Mean temperature across bucket. |
| | `moisture_avg` | FLOAT | Yes | Nullable | Mean soil moisture across bucket. |
| | `reading_count` | INTEGER | No | Default `0` | Number of raw samples rolled into aggregate. |
| **`satellite_scenes`** | `id` | UUID | No | PRIMARY KEY, default uuid4 | Unique identifier for satellite acquisition. |
| | `field_id` | UUID | No | FK -> `fields.id`, INDEXED | Foreign key of field. |
| | `provider_scene_id` | VARCHAR(128) | No | INDEXED | Satellite constellation scene ID. |
| | `acquired_at` | TIMESTAMPTZ | No | INDEXED | Timestamp satellite sensor captured imagery. |
| | `cloud_percent`| FLOAT | Yes | Nullable | Cloud cover percentage across field polygon. |
| | `ndvi_image_path` | VARCHAR(512) | Yes | Nullable | File path to cached NDVI color-mapped raster tile. |
| **`field_recommendations`** | `id` | UUID | No | PRIMARY KEY, default uuid4 | Unique recommendation identifier. |
| | `field_id` | UUID | No | FK -> `fields.id`, INDEXED | Target field receiving advice. |
| | `category` | VARCHAR(64) | No | Required | Advice domain: `'irrigation'`, `'fertilizer'`, `'disease'`. |
| | `priority` | VARCHAR(32) | No | Default `'medium'` | Severity: `'low'`, `'medium'`, `'high'`. |
| | `advice` | TEXT | No | Required | Natural language agronomic instruction. |
| | `confidence` | FLOAT | Yes | Nullable | AI model confidence score (0.0 to 1.0). |
| | `expert_status`| VARCHAR(32) | No | Default `'pending_review'` | State: `'pending_review'`, `'approved'`, `'rejected'`. |
| | `expert_notes` | TEXT | Yes | Nullable | Clinical notes appended by reviewing agronomist. |
| | `reviewed_by_id` | UUID | Yes | FK -> `users.id` | User ID of agronomist performing review. |
| | `reviewed_at` | TIMESTAMPTZ | Yes | Nullable | Timestamp of agronomist approval/rejection. |
| **`ai_chat_threads`** | `id` | UUID | No | PRIMARY KEY, default uuid4 | Unique thread identifier. |
| | `field_id` | UUID | No | FK -> `fields.id`, UNIQUE | 1-to-1 association with field. |
| | `rolling_summary` | TEXT | Yes | Nullable | Rolling conversational summary for context persistence. |
| **`ai_chat_messages`** | `id` | UUID | No | PRIMARY KEY, default uuid4 | Unique message identifier. |
| | `thread_id` | UUID | No | FK -> `ai_chat_threads.id` | Associated chat thread. |
| | `role` | VARCHAR(32) | No | Required | Message author: `'user'`, `'assistant'`, `'system'`. |
| | `content` | TEXT | No | Required | Text body of chat message. |
| **`chat_attachments`** | `id` | UUID | No | PRIMARY KEY, default uuid4 | Unique attachment identifier. |
| | `message_id` | UUID | No | FK -> `ai_chat_messages.id` | Associated message. |
| | `storage_key` | VARCHAR(512) | No | Required | Disk storage path to sanitized crop photo. |
| | `sha256` | VARCHAR(64) | No | Required | Cryptographic hash of image data. |
| **`field_season_memory`** | `id` | UUID | No | PRIMARY KEY, default uuid4 | Unique season memory identifier. |
| | `field_id` | UUID | No | FK -> `fields.id`, UNIQUE | 1-to-1 association with field. |
| | `narrative` | TEXT | Yes | Nullable | 1,200-character lifecycle memory narrative. |
| **`ai_settings`** | `id` | UUID | No | PRIMARY KEY, default uuid4 | Global AI configuration identifier. |
| | `mode` | VARCHAR(32) | No | Default `'gemini'` | Execution mode: `'gemini'`, `'free'`, `'mock'`. |
| | `model` | VARCHAR(64) | No | Default `'gemini-2.5-flash'`| Model checkpoint identifier. |

---

# 11. Interface Design

The AgriVision interface architecture follows a dual-client design strategy: a mobile-first native iOS application optimized for farmers operating outdoors in high-glare field conditions, and a responsive web application optimized for certified agronomists and administrators analyzing geospatial data on desktop workstations.

## 11.1 Global Design System & Tokens
* **Typography:**
  * *iOS Native:* Apple San Francisco (SF Pro Display for headlines, SF Pro Text for telemetry metrics and data tables).
  * *Web Application:* Inter / Outfit (Google Fonts) with standardized scale (Display 32px, Heading 24px, Body 16px, Micro 12px).
* **Curated Color Palette:**
  * *Primary Emerald:* `#10B981` (Vibrant agricultural green, healthy vegetative state, positive confirmation).
  * *Forest Slate:* `#064E3B` (Deep green anchor for navigation bars and headers).
  * *Accent Ocean:* `#0284C7` (Hydration metrics, water index NDWI, interactive links).
  * *Warning Amber:* `#F59E0B` (Moderate moisture deficit, pending expert review, non-critical alerts).
  * *Critical Crimson:* `#EF4444` (Severe drought stress, toxic dosage warning, rejected advice, battery <20%).
  * *Canvas Background:* `#F8FAFC` (Light glare-reducing background for outdoor iOS use) / `#0F172A` (Dark slate theme for Web GIS view).

---

## 11.2 iOS Mobile Screen Blueprints

### Blueprint 11.2.1: Authentication & Onboarding
* **Purpose:** Secure entry point via Firebase Auth with role-aware session resolution.
* **Layout Structure (Top to Bottom):**
  1. *Header:* Centered AgriVision leaf-aperture logo, bold greeting "Precision Agronomy at Scale".
  2. *Form Inputs:* Floating label text fields for Email Address and Password with show/hide password toggle.
  3. *Action Controls:* Full-width Primary Emerald button: "Sign In"; Outlined Secondary button: "Continue with Google".
  4. *Footer:* "Forgot Password?" link and toggle to "Create Farmer Account".

### Blueprint 11.2.2: Field Boundary Setup (Interactive MapKit Drawing)
* **Purpose:** Allows farmers to georeference field acreage for automated satellite sync.
* **Layout Structure (Top to Bottom):**
  1. *Top Navigation Bar:* "Draw Field Boundary" title, "Cancel" left button, "Save" right button.
  2. *Interactive Map Canvas (75% Screen):* Full-screen Apple MapKit with satellite raster base.
     * Floating GPS crosshair button to snap map center to user's real-time coordinates.
     * Touch gesture listeners allowing the user to tap and drop boundary pins connected by green vector lines.
     * Dynamic area counter pill displaying calculated acreage (e.g., "12.4 Hectares").
  3. *Bottom Sheet (Slide Up):* Text Input: "Field Name"; Dropdown Picker: "Crop Type"; Date Picker: "Plantation Date"; Sync Status Badge: "AgroMonitoring Automatic Sync Ready".

### Blueprint 11.2.3: Farmer Field Dashboard
* **Purpose:** The primary operational hub showing tri-source synthesized telemetry.
* **Layout Structure (Top to Bottom):**
  1. *Top Bar:* Field selector dropdown pill, notification bell icon with unread badge, and user avatar.
  2. *Satellite Hero Card:* High-resolution truecolor satellite crop snapshot overlaid with vegetative health pill (e.g., "NDVI: 0.68 - Vigorous Growth") and local weather forecast card (Current Temp, 5-day rain probability).
  3. *Live IoT Telemetry Grid (2x2 Card Matrix):*
     * *Card 1 (Soil Moisture):* Circular progress gauge (0–100%) with status badge ("Optimal: 42%").
     * *Card 2 (Soil Temperature):* Digital readout with trend arrow ("22.4°C / Stable").
     * *Card 3 (NPK Balance):* Horizontal segmented bars showing Nitrogen, Phosphorus, Potassium levels.
     * *Card 4 (Sensor Battery & Health):* Battery gauge (e.g., "94% Battery") and last seen timestamp ("Synced 2m ago").
  4. *Actionable AI Advice Banner:* High-contrast card with priority icon (e.g., "Agronomist Approved: Irrigate 15mm within 4 hours to avoid heat stress").
  5. *Bottom Tab Bar:* `Dashboard`, `Fields`, `AI Chat`, `Hardware`, `Settings`.

### Blueprint 11.2.4: Multi-Modal AI Agronomist Chat
* **Purpose:** Interactive conversational diagnosis of crop symptoms and leaf diseases.
* **Layout Structure (Top to Bottom):**
  1. *Header Bar:* "AI Agronomy Advisor" with pulsing green connection dot and active field indicator.
  2. *Chat Message Scroll View:* User Bubbles (right-aligned, photo thumbnails); Assistant Bubbles (left-aligned, rich markdown); Safety Notice (inset red card if advice involves chemical treatments).
  3. *Input Dock (Pinned to Bottom):* Camera Button (instant shutter); Photo Library Button; Text Input; Emerald Send Button.

---

## 11.3 Web Application Screen Blueprints (Agronomist & Admin Portal)

### Blueprint 11.3.1: Multi-Spectral GIS Map View (`GISMapView`)
* **Purpose:** Desktop GIS workstation for analyzing satellite spectral indices across regional fields.
* **Layout Structure:**
  1. *Sidebar (Left 25%):* Field Portfolio List with search; Layer Control Panel with radio buttons for 8 Spectral Layers (`NDVI`, `NDWI`, `EVI`, `Truecolor`, `Falsecolor`, `EVI2`, `NRI`, `DSWI`); Layer Opacity Slider (0% to 100%); Spectral Legend Scale.
  2. *Map Canvas (Right 75%):* MapLibre GL vector canvas with satellite base; GeoJSON vector field boundaries; Custom raster tile layer dynamically requesting `/api/fields/{id}/satellite/latest/tile/{layer}/{z}/{x}/{y}` with Bearer auth injection; Popup inspector on field click displaying crop history and AI health score.

### Blueprint 11.3.2: Human-in-the-Loop AI Advisory Review Queue (`AIAdvisoryView`)
* **Purpose:** Clinical review portal for certified agronomists to validate or reject AI-generated chemical and high-risk recommendations.
* **Layout Structure:**
  1. *Header:* "AI Advisory Validation Center" with summary metrics (Pending Review, Approved Today, Rejected).
  2. *Pending Review Feed:* Stack of expandable recommendation review cards showing Field Name, Farmer Owner, Urgency Badge ("CRITICAL - PESTICIDE DOSAGE"), Telemetry Context Snapshot, Prescribed Advice with active ingredients, and Clinical Justification.
  3. *Action Modal / Buttons:* Green "Approve Recommendation" Button; Red "Reject Recommendation" Button; "Edit Advice" Button.
  4. *Steering Guidance Drawer:* Text area enabling agronomists to inject authoritative guidance notes directly into the field's AI reasoning memory.

### Blueprint 11.3.3: IoT Hardware Fleet & Provisioning (`IoTHardwareView`)
* **Purpose:** Hardware inventory, live telemetry health, and device pairing management.
* **Layout Structure:**
  1. *Top Action Bar:* "Pair New Sensor" button, MQTT Broker status indicator, and battery health filter.
  2. *Hardware Fleet Data Table:* Columns: Device ID, Assigned Field, Sensor Type, Soil Moisture, Ground Temp, Battery Gauge (Color-coded progress bar), Signal/Last Seen, Actions.
  3. *Pairing Modal (Popup):* Input for `device_id` (e.g., "ESP32_01AB"); Target Field dropdown; "Verify & Pair" Button with loading spinner and instant fleet refresh.

### Blueprint 11.3.4: Team & Multi-Tenant Access Management (`UsersView`)
* **Purpose:** Administration of enterprise team members, roles, and invitation workflows.
* **Layout Structure:**
  1. *Header Bar:* "Team & Access Control", active tenant identifier, and "Invite Staff Member" button.
  2. *Active Staff Table:* Columns: User Name, Email, Role Badge (`admin`, `agronomist`, `mobile_user`), Status (`Active`), Date Joined.
  3. *Pending Invitations Section:* Table displaying sent invitations, target roles, expiration timestamps, and "Resend / Revoke" controls.
  4. *Invitation Modal:* Email address input (case-insensitive); Role selection (`Agronomist` or `Mobile User`); "Send Invitation" button.
"""

# Write the master markdown file
with open(md_path, "w", encoding="utf-8") as f:
    f.write(content)

print(f"Generated unified markdown: {md_path} ({len(content)} bytes)")

# Also compile HTML with clean embedded styling
import re, html

def generate_clean_html(md_text):
    # Process images: ensure diagrams render cleanly
    text = md_text

    # Replace mermaid code blocks with pre tags
    text = re.sub(r'```mermaid\n(.*?)\n```', r'<pre class="mermaid">\1</pre>', text, flags=re.DOTALL)

    # Convert headers
    text = re.sub(r'^# (.*?)$', r'<h1>\1</h1>', text, flags=re.MULTILINE)
    text = re.sub(r'^## (.*?)$', r'<h2>\1</h2>', text, flags=re.MULTILINE)
    text = re.sub(r'^### (.*?)$', r'<h3>\1</h3>', text, flags=re.MULTILINE)
    text = re.sub(r'^#### (.*?)$', r'<h4>\1</h4>', text, flags=re.MULTILINE)

    # Convert horizontal dividers
    text = re.sub(r'^---$', '<hr class="chapter-divider" />', text, flags=re.MULTILINE)

    # Images
    text = re.sub(r'!\[(.*?)\]\((.*?)\)', r'<div class="diagram-container"><img src="\2" alt="\1" class="diagram-img" /><p class="diagram-caption">\1</p></div>', text)

    # Inline formatting
    text = re.sub(r'\*\*(.*?)\*\*', r'<strong>\1</strong>', text)
    text = re.sub(r'\*(.*?)\*', r'<em>\1</em>', text)
    text = re.sub(r'`([^`]+)`', r'<code>\1</code>', text)

    # Tables
    def parse_table(match):
        lines = match.group(0).strip().split('\n')
        if len(lines) < 2:
            return match.group(0)
        headers = [c.strip() for c in lines[0].strip('|').split('|')]
        out = ['<div class="table-responsive"><table><thead><tr>']
        for h in headers:
            out.append(f'<th>{h}</th>')
        out.append('</tr></thead><tbody>')
        for row in lines[2:]:
            cols = [c.strip() for c in row.strip('|').split('|')]
            out.append('<tr>')
            for c in cols:
                out.append(f'<td>{c}</td>')
            out.append('</tr>')
        out.append('</tbody></table></div>')
        return '\n'.join(out)

    text = re.sub(r'(?:^\|.*?\|\n)+', parse_table, text, flags=re.MULTILINE)

    # Unordered Lists
    def parse_list(match):
        items = re.findall(r'^\s*[\*\-]\s+(.*?)$', match.group(0).strip(), flags=re.MULTILINE)
        return '<ul>\n' + '\n'.join([f'  <li>{item}</li>' for item in items]) + '\n</ul>'
    text = re.sub(r'(?:^\s*[\*\-]\s+.*?\n)+', parse_list, text, flags=re.MULTILINE)

    # Numbered Lists
    def parse_num_list(match):
        items = re.findall(r'^\s*\d+\.\s+(.*?)$', match.group(0).strip(), flags=re.MULTILINE)
        return '<ol>\n' + '\n'.join([f'  <li>{item}</li>' for item in items]) + '\n</ol>'
    text = re.sub(r'(?:^\s*\d+\.\s+.*?\n)+', parse_num_list, text, flags=re.MULTILINE)

    # Paragraphs
    paras = text.split('\n\n')
    parsed_paras = []
    for p in paras:
        p_strip = p.strip()
        if not p_strip:
            continue
        if p_strip.startswith('<h') or p_strip.startswith('<ul') or p_strip.startswith('<ol') or p_strip.startswith('<div') or p_strip.startswith('<hr') or p_strip.startswith('<pre'):
            parsed_paras.append(p_strip)
        else:
            parsed_paras.append(f'<p>{p_strip}</p>')

    return '\n\n'.join(parsed_paras)

html_body = generate_clean_html(content)

html_template = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AgriVision - Software Requirements Specification (SRS)</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
  <style>
    :root {{
      --primary: #059669;
      --primary-dark: #065f46;
      --primary-light: #ecfdf5;
      --text-main: #1e293b;
      --text-muted: #64748b;
      --border-color: #e2e8f0;
      --bg-surface: #ffffff;
      --bg-subtle: #f8fafc;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      line-height: 1.7;
      color: var(--text-main);
      background-color: var(--bg-subtle);
      margin: 0;
      padding: 40px 20px;
    }}
    .document-container {{
      max-width: 1100px;
      margin: 0 auto;
      background: var(--bg-surface);
      padding: 60px 80px;
      border-radius: 12px;
      box-shadow: 0 4px 20px -2px rgba(0, 0, 0, 0.05), 0 2px 6px -1px rgba(0, 0, 0, 0.03);
      border: 1px solid var(--border-color);
    }}
    h1 {{
      font-size: 2.2rem;
      font-weight: 700;
      color: var(--primary-dark);
      border-bottom: 2px solid var(--primary);
      padding-bottom: 12px;
      margin-top: 50px;
      margin-bottom: 24px;
    }}
    .document-container > h1:first-of-type {{
      font-size: 2.6rem;
      text-align: center;
      border-bottom: none;
      color: #0f172a;
      margin-top: 0;
      margin-bottom: 40px;
    }}
    h2 {{
      font-size: 1.45rem;
      font-weight: 600;
      color: #0f172a;
      margin-top: 36px;
      margin-bottom: 16px;
      padding-bottom: 6px;
      border-bottom: 1px solid var(--border-color);
    }}
    h3 {{
      font-size: 1.2rem;
      font-weight: 600;
      color: #334155;
      margin-top: 24px;
      margin-bottom: 12px;
    }}
    p, li {{ font-size: 1.02rem; color: #334155; }}
    ul, ol {{ padding-left: 28px; margin-bottom: 20px; }}
    li {{ margin-bottom: 8px; }}
    code {{
      font-family: 'JetBrains Mono', monospace;
      font-size: 0.9em;
      background: #f1f5f9;
      color: #0f172a;
      padding: 2px 6px;
      border-radius: 4px;
      border: 1px solid #e2e8f0;
    }}
    pre {{
      background: #0f172a;
      color: #f8fafc;
      padding: 18px 24px;
      border-radius: 8px;
      overflow-x: auto;
      font-size: 0.9rem;
      line-height: 1.5;
    }}
    .table-responsive {{
      overflow-x: auto;
      margin: 28px 0;
      border: 1px solid var(--border-color);
      border-radius: 8px;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      text-align: left;
      font-size: 0.92rem;
    }}
    th {{
      background-color: #f8fafc;
      color: #0f172a;
      font-weight: 600;
      padding: 12px 14px;
      border-bottom: 1px solid var(--border-color);
    }}
    td {{
      padding: 12px 14px;
      border-bottom: 1px solid var(--border-color);
      color: #334155;
      vertical-align: top;
    }}
    tr:hover td {{ background-color: #f8fafc; }}
    .chapter-divider {{
      border: 0;
      height: 1px;
      background: linear-gradient(to right, transparent, #cbd5e1, transparent);
      margin: 50px 0;
    }}
    .diagram-container {{
      margin: 32px 0;
      padding: 20px;
      background: #ffffff;
      border: 1px solid var(--border-color);
      border-radius: 10px;
      text-align: center;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
    }}
    .diagram-img {{
      max-width: 100%;
      height: auto;
      border-radius: 6px;
    }}
    .diagram-caption {{
      margin-top: 10px;
      font-size: 0.9rem;
      font-weight: 500;
      color: var(--text-muted);
    }}
    @media print {{
      body {{ background: white; padding: 0; }}
      .document-container {{ box-shadow: none; border: none; padding: 0; max-width: 100%; }}
      h1 {{ page-break-before: always; }}
      .diagram-container {{ page-break-inside: avoid; }}
    }}
  </style>
</head>
<body>
  <div class="document-container">
    {html_body}
  </div>
</body>
</html>
"""

with open(html_path, "w", encoding="utf-8") as f:
    f.write(html_template)

print(f"Generated clean HTML: {html_path} ({len(html_template)} bytes)")
