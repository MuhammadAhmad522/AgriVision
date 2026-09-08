# 2. Functional Requirements & Non Functional requirements

## 2.1 Functional Requirements (FR)

### Module 1: Field GIS & Geospatial Remote Sensing
* **FR-1 (Field Boundary Creation):** The system shall allow authenticated farmers to draw, edit, and delete closed field boundaries using PostGIS polygons with a minimum of 3 vertices, enforcing topological validity (`ST_IsValid`) and surface area calculation (`area_ha`).
* **FR-2 (Crop & Lifecycle Tracking):** The system shall associate each field with a crop type (e.g., Wheat, Cotton, Rice), plantation date, expected harvest date, and seasonal status (`active`, `archived`).
* **FR-3 (Satellite Constellation Synchronization):** Upon field boundary creation, the system shall automatically synchronize with AgroMonitoring to register the polygon and fetch Sentinel-2 imagery, cloud-masked NDVI vegetation rasters, and 5-day weather forecasts.
* **FR-4 (Multi-Spectral Raster Delivery):** The tile endpoint `GET /api/fields/{id}/satellite/latest/tile/{layer}/{z}/{x}/{y}` shall accept eight spectral layer types (NDVI, NDWI, EVI, Truecolor, Falsecolor, EVI2, NRI, DSWI), reject any other layer name with `400 invalid_layer`, and require a valid bearer token on every tile request. The Web GIS portal shall present the layers verified as available for the active scene with an adjustable opacity control.

### Module 2: IoT Sensor Hardware Telemetry & Ingestion
* **FR-5 (Sensor Provisioning & Pairing):** System administrators and farmers shall be able to register physical ESP32 hardware devices via unique `device_id` strings and bind them to specific fields.
* **FR-6 (MQTT Telemetry Stream Ingestion):** The platform shall ingest MQTT telemetry packets published to topic `agrivision/sensors/{device_id}/readings`. The payload contract accepts soil moisture (ADC GPIO 5), ground temperature (DS18B20 GPIO 6), humidity, pH, EC, NPK and battery level; the currently deployed node populates temperature and moisture, and the ingestion worker accepts partial payloads so additional channels require no code change.
* **FR-7 (Time-Series Deduplication & Upsert):** The ingestion worker shall write incoming sensor samples to a TimescaleDB hypertable utilizing `ON CONFLICT (time, sensor_id) DO UPDATE` to eliminate duplicate readings during network re-transmissions.
* **FR-8 (Hourly Statistical Rollup & Pruning):** An automated in-process background worker shall aggregate raw readings every hour into statistical buckets (`sensor_readings_hourly`: Min, Max, Avg, Count) via an idempotent upsert, and shall prune raw samples beyond the retention window once daily to preserve database performance (14 days by default, overridable per field through `fields.interval_overrides.retention_days`).

### Module 3: Generative AI Advisory & Multi-Modal Diagnostics
* **FR-9 (Multi-Modal Disease Pathology Chat):** Farmers shall be able to submit up to three crop images and a textual query (maximum 2,000 characters) per turn through the mobile app, receiving grounded diagnostic feedback powered by Google Gemini on Vertex AI. Each turn is idempotent under a client-supplied `Idempotency-Key` header and is rate-limited to 20 turns per field per hour.
* **FR-10 (Autonomous Reasoning Engine):** An asynchronous background scheduler (`ai_reasoning_loop`) shall periodically evaluate field context (sensor thresholds, satellite NDVI dips, weather forecasts) against agronomic rule matrices to generate proactive advice without user prompting.
* **FR-11 (Season Memory Narrative Compression):** The system shall summarize field events, chemical applications, and stress alerts into a rolling 1,200-character narrative (`field_season_memory`) to maintain long-term context across multi-month farming seasons.
* **FR-12 (Contextual RAG Retrieval):** The AI advisor shall ground its responses using Vertex AI Search indexed against official Punjab Agricultural Extension guides, disease pathology manuals, and approved fertilizer tables.

### Module 4: Human-in-the-Loop Clinical Validation & Agronomist Queue
* **FR-13 (Chemical Dosage Interception):** The system shall intercept any AI-generated recommendation containing pesticide, fungicide, herbicide or chemical dosage indicators, setting `safety_level="high_risk"`, `requires_expert_confirmation=True` and holding `expert_status="pending"` until an agronomist rules on it.
* **FR-14 (Clinical Validation Portal):** Agronomists shall be provided with a dedicated web interface (`AIAdvisoryView`) to inspect pending recommendations, review the field's sensor/satellite context, and approve, reject, or edit the advice.
* **FR-15 (Authoritative Agronomic Steering):** Agronomists shall have the capability to inject private guidance notes directly into a field's AI memory, constraining subsequent LLM conversational behavior for that specific field.
* **FR-16 (Verified Review Notification):** Once an agronomist approves or rejects a recommendation, the system shall create a `user_notifications` record addressed to the field owner, carrying the verdict, the advice summary, the reviewer's clinical note, the originating field and a `recommendation` reference, delivered to the clients through `GET /api/notifications`. (Remote APNs/FCM push delivery is a planned enhancement and is not implemented in the current build.)

### Module 5: User Management, Invitations & Multi-Tenant Security
* **FR-17 (Firebase Authentication & Session Bootstrap):** The system shall verify Firebase ID tokens on every request, mapping the authenticated identity to the internal PostgreSQL `users` table via `firebase_uid`.
* **FR-18 (Role-Based Access Control):** The platform shall enforce strict role segregation between `mobile_user` (Farmer), `agronomist` (Specialist), and `admin` (System Owner) across all REST endpoints.
* **FR-19 (Staff Invitations & Role Elevation):** Administrators shall be able to invite agronomists and staff by email address with a pre-assigned role. The API persists the invitation in `invitations` with status `pending`, and the web portal dispatches a Firebase passwordless sign-in link (`sendSignInLinkToEmail`) to that address, which `InviteAcceptView` completes via `signInWithEmailLink`. On the invitee's first `POST /api/session/bootstrap`, a pending invitation matching their authenticated email elevates their role and is marked `accepted`.
* **FR-20 (Dynamic AI Configuration Management):** Administrators shall have the capability to tune AI temperature, reasoning thresholds, safety guardrail triggers, and polling intervals dynamically via `system_settings` without redeploying code.

## 2.2 Non-Functional Requirements (NFR)

| NFR Code | Requirement Category | Metric / Specification | Architectural Implementation |
| :--- | :--- | :--- | :--- |
| **NFR-1** | **API Response Latency** | p95 < 200ms for REST endpoints; p95 < 3.5s for AI inference | Async FastAPI async/await handlers, connection pooling, and cached tile proxies |
| **NFR-2** | **Telemetry Throughput & Flood Control** | Sustains the deployed fleet at a 5-second per-node publish cadence; per-device ingress capped at 120 messages / 60 s | Eclipse Mosquitto broker, Paho-MQTT consumer with an async queue and 50-row batch writer, per-device token window |
| **NFR-3** | **Data Retention & Aggregation** | 14-day raw sensor retention (per-field override); hourly aggregates retained indefinitely | TimescaleDB hypertable plus an application-level hourly upsert rollup worker and a daily 03:00 UTC pruning pass |
| **NFR-4** | **Service Availability & Recovery** | All core containers self-restart after failure or host reboot | Docker Compose orchestration with `restart: always` and a `pg_isready` healthcheck gating dependent services |
| **NFR-5** | **Spatial Query Performance** | Polygon containment & area queries resolve in < 50ms | PostGIS GiST spatial indexing on all `fields.boundary` geometries (SRID 4326) |
| **NFR-6** | **Security & Privacy** | Zero credential storage in the application tier; zero EXIF leakage in uploads | Firebase-issued JWT verification (credentials never reach the backend), server-side EXIF scrubbing and JPEG re-encoding via Pillow, per-user rate limiting, request body size caps and `no-store` / `nosniff` response headers |
| **NFR-7** | **Firmware Fault Tolerance** | Node recovers unattended from WiFi and broker dropouts; faulty probes never emit fabricated values | Non-blocking millis-scheduled Arduino `loop()` reconnect state machine, open/short-circuit probe thresholds, and telemetry suppression when no channel is valid |
| **NFR-8** | **Client Cross-Platform Fidelity** | Consistent data presentation across iOS and Web | Shared REST/JSON API schemas validated via Pydantic 2.0 and TypeScript strict types |
