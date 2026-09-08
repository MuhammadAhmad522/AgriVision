# 1. Scope of the Project

## 1.1 Project Overview & Mission
**AgriVision** is an enterprise-grade, multi-tenant precision agriculture and agronomic intelligence platform. The core objective of the system is to continuously monitor, evaluate, and optimize crop health across the entire farming lifecycle. AgriVision achieves this by synthesizing tri-source environmental telemetry—macro-level multi-spectral satellite imagery, micro-level physical IoT ground sensors, and user-submitted multi-modal visual observations—coupled with advanced generative AI reasoning and Human-in-the-Loop (HITL) agronomist validation.

By bridging complex geospatial remote sensing, low-power edge computing, and conversational artificial intelligence, AgriVision translates raw agronomic indicators into actionable, safety-guarded guidance. This empowers farmers to maximize crop yields, conserve water and soil nutrients, and mitigate biological and climatological risks with scientific precision.

## 1.2 Target Audience & Stakeholders
The platform strictly implements access control across three authenticated roles and key agricultural stakeholders:
1. **Farmers (`mobile_user`):** Field owners and agricultural workers who utilize the native iOS mobile application to map field boundaries, inspect live sensor telemetry, track satellite vegetative health, receive verified recommendations, and converse directly with the AI Agronomist for immediate crop diagnostics.
2. **Agronomists & Crop Specialists (`agronomist`):** Certified agricultural scientists who utilize the Web Application portal to monitor regional field portfolios, review and approve high-risk AI-generated recommendations (pesticide/chemical dosages), inject authoritative guidance to steer AI conversational responses, and analyze multi-spectral satellite rasters.
3. **System Administrators (`admin`):** Platform managers who oversee system health, configure dynamic AI model hyperparameters and reasoning prompts, manage hardware sensor provisioning, monitor ingestion pipelines, and administer multi-tenant staff invitations and access policies.
4. **Agricultural Enterprises & Extension Services:** Cooperatives seeking centralized visibility over distributed farm acreage, sensor fleet telemetry, and automated compliance audits.

## 1.3 In-Scope System Subsystems
The platform encompasses five core subsystems implemented across the codebase:

### 1. Multi-Spectral Satellite Remote Sensing & GIS Engine
* **Vector Boundary Georeferencing:** Interactive drawing and validation of field boundaries using PostGIS polygons, enforcing vertex topological integrity and surface area limits.
* **Automated Satellite Ingestion:** Automated synchronization with AgroMonitoring and Sentinel-2 satellite constellations to retrieve cloud-masked surface imagery, NDVI vegetation indices, soil moisture profiles, UV indices, and 5-day weather forecasts.
* **Multi-Layer Spectral Tile Rendering:** An authenticated tile proxy that streams provider rasters through the backend for eight spectral index types — NDVI (vegetation health), NDWI (water stress), EVI (enhanced vegetation), Truecolor (RGB), Falsecolor (infrared), EVI2 (two-band enhanced), NRI (nitrogen reflectance) and DSWI (disease-water stress). The web GIS toolbar currently exposes the four the provider serves reliably for these polygons (NDVI, NDWI, EVI, Truecolor); the remaining four are accepted by the endpoint and become selectable as soon as the provider returns them.

### 2. Physical IoT Sensor Array & Telemetry Ingestion Pipeline
* **ESP32-S3 Edge Sensor Nodes:** Physical microcontrollers deployed in fields. The node built and validated to date measures volumetric soil moisture (calibrated 12-bit ADC on GPIO 5, with open-circuit and short-circuit probe fault detection) and soil temperature (Dallas DS18B20 1-Wire bus on GPIO 6). The telemetry contract, ingestion pipeline and `sensor_readings` hypertable additionally carry humidity, pH, electrical conductivity (EC) and nitrogen-phosphorus-potassium (NPK) channels, so probes for those metrics can be added to the node without any schema or API change.
* **Resilient Non-Blocking Edge Firmware:** Arduino-framework C++ firmware built with PlatformIO for the `esp32-s3-devkitc-1-n16r8` board. It runs a non-blocking `loop()` state machine (millis-based scheduling, never `delay()`-blocked on the network) covering WiFi and MQTT reconnection, OTA firmware update, a NeoPixel status indicator, probe fault detection that suppresses NaN and disconnected readings rather than publishing zeros, and authenticated MQTT publication on a 5-second cadence.
* **High-Throughput Time-Series Ingestion:** Eclipse Mosquitto MQTT broker integrated with an asynchronous FastAPI consumer that subscribes to `agrivision/sensors/+/readings`, applies a per-device flood limit (120 messages per 60 seconds) and a 5-minute clock-skew guard, queues accepted samples, and batch-writes up to 50 rows at a time into a PostgreSQL / TimescaleDB hypertable with primary-key conflict handling on `(time, sensor_id)`.
* **Automated Time-Series Rollup:** An in-process hourly worker that aggregates raw readings into statistical buckets (`sensor_readings_hourly`: Min, Max, Avg, Count over a rolling 24-hour window) to power responsive analytics dashboards, and prunes raw samples once per day at 03:00 UTC beyond the retention window (14 days by default, overridable per field).

### 3. Generative AI Advisory Engine & Multi-Modal Diagnostics
* **Multi-Modal Crop Disease Diagnostics:** Native camera integration allowing farmers to submit up to three crop photos per turn. The backend enforces privacy-preserving EXIF stripping, re-encoding to JPEG and downscaling to a maximum edge of 2,048 px, then performs multi-modal visual inspection via Google Gemini on Vertex AI (model configurable through `GOOGLE_AI_MODEL`; `gemini-3.7-flash` by default).
* **Retrieval-Augmented Generation (RAG):** Contextual grounding of AI queries against localized agricultural knowledge repositories (Punjab Agricultural Extension, disease pathology databases, and crop-specific management guides).
* **Autonomous AI Reasoning Loop (`ai_reasoning_loop`):** Background scheduler that continuously evaluates multi-source field context (sensor trends, weather forecasts, satellite anomalies) against agronomic rule matrices to synthesize field-specific recommendations without requiring manual user initiation.
* **Season Memory Narrative:** Rolling 1,200-character crop season memory (`field_season_memory`) that continuously summarizes key lifecycle milestones, applied treatments, and sensor stresses to maintain persistent multi-month LLM reasoning context without token exhaustion.

### 4. Human-in-the-Loop (HITL) Safety Guardrails & Expert Steering
* **Pesticide & Chemical Dosage Interception:** Rule-based safety guardrails in `_apply_safety_policy` that detect chemical, dosage and other high-risk interventions, force `safety_level = "high_risk"` and `requires_expert_confirmation = True`, and hold the recommendation at `expert_status = "pending"` until a certified agronomist rules on it.
* **Clinical Review Queue:** Dedicated desktop web portal (`AIAdvisoryView`) enabling agronomists to approve, reject, or modify intercepted recommendations before they reach the farmer.
* **Authoritative AI Guidance Injection:** Private Agronomist steering drawer that injects clinical directives directly into the field's LLM context memory, steering all subsequent AI responses for that farm.

### 5. Dual Client Presentation Applications
* **Native iOS Mobile App (SwiftUI & UIKit):** Built with Swift, SwiftUI, Combine and Apple MapKit on an MVVM-C (Model-View-ViewModel-Coordinator) architecture. Provides farmers with Firebase email/password and Google federated sign-in, interactive polygon drawing, live sensor gauge cards, an in-app notification centre, and multi-modal camera chat with the AI agronomist.
* **Enterprise Web GIS Portal (React 19 & TypeScript):** Built with React 19, Vite, TypeScript, Tailwind CSS 4 and MapLibre GL, with TanStack Query for server state, Zustand for client state and Recharts for time-series visualisation. Provides desktop workstations with interactive multi-spectral raster GIS inspection, IoT hardware fleet pairing, analytics charts and team invitation management.

## 1.4 Out-of-Scope System Boundaries
To maintain rigorous engineering focus, the following elements are explicitly defined as out-of-scope:
* Autonomous tractor steering, drone autopilot navigation, or CAN bus physical actuator robotics.
* Direct in-app eCommerce checkout, chemical payment processing, or agricultural supply inventory logistics.
* Custom silicon ASIC design or physical hardware injection-molding manufacturing.
* Proprietary orbital satellite constellation deployment (the platform leverages Sentinel-2 via AgroMonitoring APIs).
