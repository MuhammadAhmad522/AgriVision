# 10. Database Design

## 10.1 Relational Engine & Partitioning Architecture
The AgriVision persistence layer is hosted on PostgreSQL 15/16 utilizing the `timescale/timescaledb-ha:pg15-all` distribution. The database combines three specialized storage paradigms within a single unified engine:
1. **Relational Core (PostgreSQL):** Stores entities requiring ACID transactional guarantees (Users, Invitations, Fields, Recommendations, Settings).
2. **Spatial Engine (PostGIS):** Manages vector field boundaries (Polygons, MultiPolygons) in spatial reference system WGS 84 (SRID 4326), with GiST spatial indexing for ultra-fast point-in-polygon and geometric intersection queries.
3. **Time-Series Hypertables (TimescaleDB):** Automatically partitions the high-volume `sensor_readings` table across 7-day chunk intervals, providing high write throughput and instant continuous aggregation.

## 10.2 PostGIS Spatial Geometry Engine
* **Spatial Reference System:** WGS 84 (EPSG:4326), aligned with GPS and satellite orbital standards.
* **Geometric Types:** `GEOMETRY(Polygon, 4326)` representing field perimeters.
* **Spatial Operations:**
  - `ST_MakePolygon(ST_GeomFromText(...))` for boundary construction from client coordinate arrays.
  - `ST_IsValid(boundary)` to prevent self-intersecting or topologically malformed field polygons.
  - `ST_Area(boundary::geography) / 10000.0` for geodetically accurate surface area computation in hectares.
  - `ST_Centroid(boundary)` for computing the central GPS coordinate for weather forecast fetching.

## 10.3 TimescaleDB Hypertable & Hourly Rollup Strategy
* **Hypertable Creation:** At application startup `sensor_readings` is converted with `SELECT create_hypertable('sensor_readings', 'time', if_not_exists => TRUE, migrate_data => TRUE)`, partitioning along the `time` dimension using TimescaleDB's default 7-day chunk interval. The conversion is guarded by `ENABLE_TIMESCALEDB`, so the schema also runs on plain PostgreSQL (as it does in the test suite).
* **Hourly Rollup (application-level, not a continuous aggregate):** `sensor_readings_hourly` is a **regular table** maintained by an in-process worker rather than a TimescaleDB continuous aggregate. Every hour the worker executes a single `INSERT ... SELECT date_trunc('hour', time) ... GROUP BY bucket, sensor_id ... ON CONFLICT (sensor_id, bucket) DO UPDATE` over the trailing 24 hours, which makes the rollup idempotent and self-healing after downtime. This was a deliberate trade-off: it keeps the schema portable to a database without the TimescaleDB extension, at the cost of the automatic refresh policy a continuous aggregate would provide.
* **Aggregated Columns:** avg/min/max for `temperature`, `moisture`, `humidity`, `ph`, `ec`, `npk_n`, `npk_p` and `npk_k` (24 statistical columns), plus `reading_count`, keyed by the composite primary key `(bucket, sensor_id)`.
* **Data Retention Policy:** Once per day at 03:00 UTC the same worker deletes raw rows older than the retention window, resolved per field as `COALESCE((fields.interval_overrides->>'retention_days')::int * INTERVAL '1 day', INTERVAL '14 days')`. Hourly aggregates are never pruned, so long-term trends survive while the raw-sample footprint stays bounded.

## 10.4 Exhaustive Data Dictionaries for Primary Tables

### Table: `fields`
| Column Name | Data Type | Nullable | Constraints & Indexes | Architectural Description |
| :--- | :--- | :--- | :--- | :--- |
| `id` | UUID | No | PRIMARY KEY, default `uuid4` | Unique identifier for the field parcel. |
| `owner_id` | UUID | No | FK -> `users.id`, INDEXED | The farmer who owns the parcel; the root of every tenancy check. |
| `name` | VARCHAR(100) | No | Required | Human-readable name of the field. |
| `crop_type` | VARCHAR(80) | Yes | Nullable | Primary crop planted (e.g. `'Wheat'`). |
| `plantation_date` | TIMESTAMPTZ | Yes | Nullable | Date the crop was sown. |
| `expected_harvest_date` | TIMESTAMPTZ | Yes | Nullable | Expected harvest date; when null the AI is expected to infer readiness. |
| `boundary` | GEOMETRY(Polygon, 4326) | No | Required, GiST INDEXED | PostGIS polygon of the field perimeter. |
| `area_ha` | DOUBLE PRECISION | No | Required, validated 1–3000 ha | Geodetically computed surface area in hectares. |
| `status` | VARCHAR(20) | No | Default `'active'`, INDEXED | Lifecycle state: `'active'` or `'archived'`. |
| `archived_at` | TIMESTAMPTZ | Yes | Nullable | When the field left the active portfolio. |
| `created_at` | TIMESTAMPTZ | No | Server default `now()` | Row creation timestamp. |
| `updated_at` | TIMESTAMPTZ | No | Server default `now()`, `onupdate` | Last modification timestamp. |
| `latest_ndvi` | DOUBLE PRECISION | Yes | Nullable | Most recent NDVI vegetation index (-1.0 to 1.0). |
| `interval_overrides` | JSONB | No | Server default `'{}'::jsonb` | Per-field overrides for sync/reasoning intervals and raw-reading retention days. |
| `latest_health_score` | DOUBLE PRECISION | Yes | Nullable | AI holistic health score (0–100); null whenever the label is `insufficient_data`. |
| `latest_health_label` | VARCHAR(20) | Yes | Nullable | Categorical health label accompanying the score. |
| `latest_health_rationale` | TEXT | Yes | Nullable | Model's stated reasoning for the current health verdict. |
| `latest_health_updated_at` | TIMESTAMPTZ | Yes | Nullable | When the health verdict was last recomputed. |

> **Note:** the external satellite polygon identifier is **not** stored on this table. It is normalised into `field_provider_links` (`provider`, `external_id`, `sync_status`, `sync_error`, `retryable`, `last_sync_at`) under `UNIQUE (field_id, provider)`, so a field can be linked to several providers and each link carries its own independent sync state.

### Table: `sensor_readings` (TimescaleDB Hypertable)
| Column Name | Data Type | Nullable | Constraints & Indexes | Architectural Description |
| :--- | :--- | :--- | :--- | :--- |
| `time` | TIMESTAMPTZ | No | COMPOSITE PK, hypertable partition key | Sample acquisition timestamp (rejected beyond ±300 s of broker clock). |
| `sensor_id` | UUID | No | COMPOSITE PK, FK -> `sensors.id` ON DELETE CASCADE | The physical node that produced the sample. |
| `temperature` | DOUBLE PRECISION | Yes | Nullable | Soil temperature in °C (DS18B20 on GPIO 6). |
| `moisture` | DOUBLE PRECISION | Yes | Nullable | Volumetric soil moisture percentage (0–100%, ADC on GPIO 5). |
| `humidity` | DOUBLE PRECISION | Yes | Nullable | Relative atmospheric humidity percentage (channel reserved for a future probe). |
| `ph` | DOUBLE PRECISION | Yes | Nullable | Soil acidity/alkalinity (0.0–14.0). |
| `ec` | DOUBLE PRECISION | Yes | Nullable | Electrical conductivity in mS/cm. |
| `npk_n` | DOUBLE PRECISION | Yes | Nullable | Soil nitrogen concentration in mg/kg. |
| `npk_p` | DOUBLE PRECISION | Yes | Nullable | Soil phosphorus concentration in mg/kg. |
| `npk_k` | DOUBLE PRECISION | Yes | Nullable | Soil potassium concentration in mg/kg. |

> **Note:** battery level is device state, not a time-series sample, and is therefore stored on `sensors.battery_level` alongside `sensors.last_seen`, both refreshed by the ingestion worker as readings arrive.

### Table: `field_recommendations`
| Column Name | Data Type | Nullable | Constraints & Indexes | Architectural Description |
| :--- | :--- | :--- | :--- | :--- |
| `id` | UUID | No | PRIMARY KEY, default `uuid4` | Unique recommendation identifier. |
| `field_id` | UUID | No | FK -> `fields.id` ON DELETE CASCADE, INDEXED | Target field receiving the advice. |
| `analysis_run_id` | UUID | Yes | FK -> `ai_analysis_runs.id` ON DELETE SET NULL | The reasoning run that produced this item; preserves provenance. |
| `category` | VARCHAR(50) | No | Required | Advice domain (e.g. `'Irrigation'`, `'Fertilizer'`, `'Pest Control'`, `'Harvest Timing'`). |
| `priority` | VARCHAR(20) | No | Default `'medium'` | Severity: `'low'`, `'medium'`, `'high'`. |
| `advice` | TEXT | No | Required | Plain-language recommendation shown to the farmer. |
| `rationale` | TEXT | Yes | Nullable | Agronomic reasoning citing NDVI, telemetry and weather. |
| `confidence` | DOUBLE PRECISION | Yes | Nullable | Model confidence (0.0–1.0). |
| `confidence_reason` | VARCHAR(500) | Yes | Nullable | Stated basis for that confidence. |
| `safety_level` | VARCHAR(20) | No | Default `'guarded'` | `'routine'`, `'guarded'` or `'high_risk'` after the safety policy runs. |
| `requires_expert_confirmation` | BOOLEAN | No | Default `false` | Set true when chemical/dosage advice or unapproved evidence is detected. |
| `evidence` | JSONB | Yes | Nullable | Approved source passages and URLs supporting the advice. |
| `expert_status` | VARCHAR(20) | No | Default `'pending'` | Review verdict: `'pending'`, `'approved'`, `'rejected'`. |
| `expert_notes` | TEXT | Yes | Nullable | Reviewing agronomist's clinical note, delivered to the farmer. |
| `status` | VARCHAR(20) | No | Default `'pending'` | Farmer-side feedback state on the advice. |
| `ndvi_at_generation` | DOUBLE PRECISION | Yes | Nullable | NDVI captured at generation time for later comparison. |
| `created_at` | TIMESTAMPTZ | No | Server default `now()` | Generation timestamp. |
| `feedback_at` | TIMESTAMPTZ | Yes | Nullable | When the farmer responded. |
| `expires_at` | TIMESTAMPTZ | Yes | Nullable | When the advice ceases to be actionable. |
| `outcome` | VARCHAR(20) | Yes | Nullable | Recorded real-world outcome after application. |
| `outcome_notes` | TEXT | Yes | Nullable | Free-text outcome detail. |
| `outcome_at` | TIMESTAMPTZ | Yes | Nullable | When the outcome was recorded. |
| `reviewed_by_id` | UUID | Yes | FK -> `users.id` ON DELETE SET NULL | Agronomist of record for the review decision. |
| `reviewed_at` | TIMESTAMPTZ | Yes | Nullable | Timestamp of the review decision. |

---

# 11. Interface Design

## 11.1 Design System Tokens & Foundations
Both clients render the same brand palette, defined once as raw hex values and mirrored in each platform's token layer — `Core/DesignSystem/Theme.swift` on iOS and the `@layer base` custom properties in `src/index.css` on the web.

### Brand Colour Palette (shared by iOS and Web)
* **Charcoal Green (`#3d6d40`):** The primary brand colour — primary action buttons, active navigation states and headline accents. Exposed as `--primary` on the web and `Theme.Colors.primary` on iOS.
* **Medium Green (`#6a8e4e`):** Secondary emphasis and mid-scale vegetation indicators (`--primary-medium` / `Theme.Colors.primaryMedium`).
* **Lime Green (`#b0d182`):** Highlight and glow colour — active borders, focus rings, healthy-vegetation indicators and the `--primary-glow` shadow (`--accent-lime` / `Theme.Colors.primaryLight`).
* **Cream (`#f4f1ea`):** Primary text on dark surfaces and the light-mode background on iOS (`--text-main` / `Theme.Colors.creamColor`).

### Web Surface & Status Tokens
The web workstation is a **dark glassmorphic** interface, not a light one: the body is painted `#0e1e11` under a dimmed field photograph, and content sits on translucent green-tinted glass.
* **Surfaces:** `--bg-main: #0e1e11`, `--bg-surface: #17321c`, `--bg-surface-elevated: #214427`, with glass fills `rgba(23,50,28,0.78)` and `rgba(30,64,36,0.65)`.
* **Borders:** lime-tinted at low alpha — `rgba(176,209,130,0.28)` rising to `0.60` on emphasis.
* **Status accents:** cyan `#38bdf8` (informational), orange `#fb923c` (warning / moderate stress), purple `#c084fc` (analytical series), red `#f87171` (critical alerts and high-risk chemical banners).
* **Text ramp:** `--text-main` cream, `--text-muted` `#cbd5e1`, `--text-dim` `#94a3b8`.
* **Radii & elevation:** an 8 / 16 / 22 / 28 px radius scale plus a pill radius, with `--shadow-glass` for depth and `--shadow-glow` for lime emphasis.

### iOS Surface & Status Tokens
The iOS client is adaptive rather than dark-only: `Theme.Colors.background`, `.surface` and `.textPrimary` resolve through `dynamicColor(light:dark:)`, pairing cream/white surfaces in light mode with near-black surfaces in dark mode. Semantic status colours map to the system palette (`.green` success, `.orange` warning, `.red` error), and spacing (4/8/12/16/24/32/48) and corner radii (8/16/24/pill) are centralised in `Theme.Spacing` and `Theme.Radius`.

### Typography
* **Web headings:** `Outfit`, letter-spaced at `-0.02em` (`--font-heading`).
* **Web body:** `Plus Jakarta Sans` (`--font-body`).
* **iOS:** the system font (SF Pro) accessed through the `Typography` text-style ladder, with weights adjusted per style so the mobile client inherits Dynamic Type and accessibility sizing for free rather than shipping a bundled typeface.

## 11.2 Native iOS Application Blueprints (SwiftUI)

### Blueprint 11.2.1: Authentication & Splash View (`SplashView` & `AuthView`)
* **Purpose:** Initial onboarding, user login, and session bootstrapping.
* **Layout Structure:**
  1. *Hero Brand Header:* AgriVision logo mark, charcoal-to-lime brand gradient, and welcome tagline.
  2. *Authentication Form:* Email text field with validation, secure password field, "Remember Me" toggle, and primary "Sign In" button.
  3. *Federated Providers:* "Sign in with Google" branded button leveraging `GoogleSignIn-iOS`.
  4. *Footer:* Password reset link and terms of service disclaimer.

### Blueprint 11.2.2: Field Dashboard & Telemetry Cards (`DashboardView`)
* **Purpose:** Primary home screen displaying active field status, environmental metrics and the AI advisory feed.
* **Layout Structure:**
  1. *Top Navigation Bar (`DashboardHeaderView`):* Field picker (parcel name, crop badge, area in ha), profile control and a notification bell opening `NotificationInboxView`.
  2. *AI Field Health Card (`HealthCardView`):* Holistic AI health score (0–100) with a categorical label and rationale, degrading to an explicit "insufficient data" state rather than showing a fabricated number.
  3. *Metric Card Grid:* Liquid-glass cards for soil moisture (`MoistureCardView`), soil temperature (`SoilTempCardView`), NDVI (`NDVICardView`), vegetation indices (`VegetationIndicesCardView`), soil pH (`PHLevelCardView`), live sensor status (`SensorLiveCardView`), soil chemistry/EC-NPK (`SensorChemistryCardView`), weather (`WeatherCardView`), forecast (`ForecastCardView`), UV index (`UVIndexCardView`), satellite imagery (`SatelliteImageCardView`) and scene quality (`SatelliteQualityCardView`). Each card pushes a matching detail screen from `Views/Detail/`.
  4. *Data Availability Card (`DataAvailabilityCard`):* States plainly which of the sensor, satellite and weather sources are currently reporting, so an empty chart is never mistaken for a zero reading.
  5. *AI Advisor Card & Alerts (`AIAdvisorCard`, `AlertsBottomSheet`):* Latest recommendations with urgency styling, expanding into a snap-to-fit bottom sheet of alert rows.
  6. *Bottom Tab Bar:* 4 tabs — **Home**, **Fields**, **Advisor**, **Settings**.

### Blueprint 11.2.3: Interactive Field Boundary Drawing (`FieldSelectionView`)
* **Purpose:** Georeferenced parcel mapping tool for digitizing field perimeters.
* **Layout Structure:**
  1. *Interactive MapKit Canvas:* Full-screen satellite base layer centered on user's current GPS location.
  2. *Drawing Overlay:* Visual polyline tracing tap points, connecting closed polygon vertices with a translucent charcoal-green fill.
  3. *Floating Action Controls:* "Undo Point" button, "Clear All" button, and computed surface area badge (`e.g., 4.25 ha`).
  4. *Save Drawer (Modal):* Bottom sheet prompting for Field Name, Crop Type dropdown, and Plantation Date picker.

### Blueprint 11.2.4: Multimodal AI Crop Diagnostics Chat (`AIChatView`)
* **Purpose:** Conversational interface for diagnosing leaf pathologies and asking agronomic questions.
* **Layout Structure:**
  1. *Header Bar:* "AI Agronomist", field context pill (`Field: North Wheat`), and session reset button.
  2. *Message Scroll Canvas:* Chat bubbles differentiating farmer questions (charcoal green) from AI responses (neutral surface), rendering markdown lists and bold text.
  3. *Camera Attachment Drawer:* Floating button to capture leaf photo via native camera or select from photo library.
  4. *Input Dock:* Multiline text input field with send icon button and processing spinner.

## 11.3 Web Application Workstation Blueprints (React 19)

### Blueprint 11.3.1: Geospatial Satellite Workstation (`GISMapView`)
* **Purpose:** Desktop GIS workstation for analysing satellite spectral indices across the field portfolio.
* **Layout Structure:**
  1. *Sidebar (`Sidebar.tsx`):* Field portfolio navigation and role-aware section links, collapsible through `useUIStore.setSidebarOpen`.
  2. *GIS Toolbar (`GISToolbar.tsx`):* Raster layer selector listing the layers verified as served for the active scene (NDVI — canopy vigour, NDWI — canopy moisture, EVI — vigour with reduced soil noise, True Color — RGB), a 2D/3D pitch toggle, and a "fit to all fields" control.
  3. *Map Canvas (`useMapLayers.ts`):* MapLibre GL canvas rendering GeoJSON field boundaries over a raster tile layer that requests `/api/fields/{id}/satellite/latest/tile/{layer}/{z}/{x}/{y}` with the bearer token injected per tile request.
  4. *Inspector Drawer (`GISInspectorDrawer.tsx`):* Slide-over panel for the selected field showing crop context, AI health score and the latest telemetry, toggled through `useUIStore.setInspectorOpen`.

### Blueprint 11.3.2: Human-in-the-Loop AI Advisory Review Queue (`AIAdvisoryView`)
* **Purpose:** Clinical review portal where agronomists validate or reject AI-generated high-risk and chemical recommendations before farmers can act on them.
* **Layout Structure:**
  1. *Header:* Advisory validation summary with pending/approved/rejected counts, sourced from `usePendingRecommendations`.
  2. *Pending Review Feed:* Expandable cards showing field name, owner, priority badge, safety level, the model's advice and rationale, and the cited evidence URLs. `useAnalysisRun` opens the originating analysis run so the reviewer can see the exact context snapshot, model name, prompt version and policy version behind the advice.
  3. *Verdict Controls:* Approve and reject actions with a clinical notes field, submitted via `useValidateRecommendation` to `POST /api/recommendations/{id}/expert-validate`; the note is delivered verbatim to the farmer's notification inbox.
  4. *Expert Advisory Composer (`AdvisoryComposer.tsx`):* Free-text advisory (title, message, priority, optional recommendation link) delivered to the field owner's inbox via `POST /api/fields/{id}/advisories`.
  5. *Agronomist Guidance Channel:* A staff-only chat thread per field (`useGuidanceHistory` / `useSendGuidance`) that is kept separate from the farmer-facing conversation, plus a re-evaluation trigger (`useTriggerReEvaluation`) that forces a fresh reasoning run.

### Blueprint 11.3.3: IoT Hardware Fleet & Provisioning (`IoTHardwareView`)
* **Purpose:** Hardware inventory, live telemetry health and device pairing management.
* **Layout Structure:**
  1. *Top Action Bar:* Pair-new-sensor control, fleet status summary, and status filters — **all**, **online**, **offline**, **unassigned** (a paired probe that is not yet on a field).
  2. *Hardware Fleet Table:* Device ID, assigned field (or "Not on a field"), owner, last-seen freshness (rendered down to "Just now" / "Never"), battery gauge, and the latest value for each telemetry channel — Temperature, Moisture, Humidity, Nitrogen, Phosphorus and Potassium — with channels the deployed node does not yet populate shown as unavailable rather than as zero.
  3. *Pairing Flow:* `useVerifySensor` checks a `device_id` against `GET /api/sensors/verify/{device_id}` before `usePairSensor` claims it, then `useAssignSensor` binds it to a field; `useDetachSensor` and `useUnpairSensor` reverse each step independently.

### Blueprint 11.3.4: Team & Multi-Tenant Access Management (`UsersView`)
* **Purpose:** Administration of staff accounts, roles and invitations. The whole view is gated on the `admin` role and renders an explicit access-denied state for anyone else.
* **Layout Structure:**
  1. *Header Bar:* Title, purpose line, and the invite form.
  2. *Invite Form:* Email input and role selector; submitting calls `POST /api/invitations` and then dispatches a Firebase sign-in link to the address, with inline success and error status.
  3. *Staff Table:* User email, role badge (`admin`, `agronomist`, `mobile_user`) styled from `ROLE_METADATA`, and account state.
  4. *Pending Invitations:* Invitations still at status `pending`, with the role they will grant and when they were issued. Invitations carry no expiry in the current schema, and are cleared by being accepted rather than by an explicit revoke action.

### Blueprint 11.3.5: Fleet Risk Triage & Analytics (`FleetAnalyticsView`)
* **Purpose:** Portfolio-level view answering which fields need attention first.
* **Layout Structure:**
  1. *KPI Row:* Total acreage, mean field health, telemetry probe count and a "needs attention" count.
  2. *Distribution Charts:* Health distribution and health-by-crop breakdowns rendered with Recharts.
  3. *Triage Table:* Field name, crop, overall health, the AI's rationale for that verdict, and a drill-down action — with explicit "awaiting AI assessment" and "no rationale recorded" states instead of blank cells.
  4. *Telemetry Provenance Panel:* "Data behind these charts" — probes online, readings in the window, newest reading and empty buckets — so a flat chart can be told apart from missing data, plus a manual telemetry refresh.

### Blueprint 11.3.6: Control Portal Configuration (`SettingsView`)
* **Purpose:** Operational status of the platform's dependencies and, for administrators, live tuning of the AI stack.
* **Layout Structure:**
  1. *Backend Connection:* Active FastAPI server URL with a live reachability indicator.
  2. *Connected External Services:* Firebase Authentication, AgroMonitoring and Vertex AI status, plus Eclipse Mosquitto broker state.
  3. *Dynamic AI Configuration (admin only):* Provider mode and model selection persisted to `system_settings` through `GET`/`PUT /api/admin/settings/ai`, so the reasoning stack can be re-pointed without a redeployment.
