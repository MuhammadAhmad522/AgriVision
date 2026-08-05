# Required QA Tests — AgriVision

Session handoff document. If context window is full, give this file to the next session for a complete understanding of what tests exist, what's missing, what bugs exist across the full stack, and what needs fixing for CI readiness.

---

## 1. Complete Data Flow (End to End)

```
iOS App ──Auth──> Firebase ──> Backend get_current_user() ──> User table
                    │
    ┌───────────────┼───────────────────────────────────────┐
    │               │                                       │
 Field Mgmt     Sensor Data                            AI Analysis
    │               │                                       │
 POST /fields   ESP32 ──MQTT──> on_message()           run_ai_for_field()
 (boundary WKT,  (validates, auto-discovers,             (builds context,
  PostGIS valid,   persists SensorReading)                 fingerprints, calls
  agro_status=                                            Gemini with schema,
  "pending")       iOS reads via                            safety filter,
     │              GET /sensor-readings                     persists recommendations)
     │                                                │
 Background sync                      ┌────────────────┤
 external_data_loop() (5min)     Chat Flow        Feedback Flow
     │                           POST /chat       POST /feedback
  AgroMonitoring API             (idempotent,     POST /outcome
  (satellite, soil,              sanitize images,
   weather, uvi)                 Gemini chat,
     │                           rolling summary)    │
  FieldObservation                                   │
  SatelliteScene                              Background Workers
  ProviderCapability                         external_data_loop()
     │                                         ai_reasoning_loop()
  Dashboard (aggregated)                      deletion_processor()
```

### Key database relationships (16 tables):
```
User (1) ──> Field (many)
Field (1) ──> Sensor (many) ──> SensorReading (many, TimescaleDB)
Field (1) ──> FieldObservation (many)
Field (1) ──> SatelliteScene (many)
Field (1) ──> AIAnalysisRun (many) ──> FieldRecommendation (many)
Field (1) ──> AIChatThread (1) ──> AIChatMessage (many) ──> ChatAttachment (many)
Field (1) ──> FieldDeletionJob (1)
Field (1) ──> ProviderCapability (many), ProviderCache (many), ProviderRequestLog (many)
```

### 3 external integrations:
- **Firebase Auth** — user authentication, token verification
- **AgroMonitoring API** — satellite imagery, soil, weather, UVI data
- **Google Gemini AI** — field recommendations, chat advice
- **MQTT** — IoT sensor data ingestion

---

## 2. Test Inventory (What Exists)

| File | Type | Count | Runtime | Dependencies |
|------|------|-------|---------|-------------|
| `tests/test_validation_and_errors.py` | Unit | 12 | ~50ms | None |
| `tests/test_agromonitoring_free_first.py` | Unit | 11 | ~100ms | Mocks only |
| `tests/test_chat_media.py` | Unit | 2 | ~200ms | PIL |
| `tests/test_multitenant_integration.py` | Integration | 10 | ~30s | Docker PostgreSQL |
| `tests/test_ai_evaluation_dataset.py` | Data integrity | 1 | ~10ms | Static dataset |

**Total: 36 tests** (25 unit, 10 integration, 1 data integrity)

---

## 3. Coverage by Component

| Component | Lines | Tests Covering It | Risk Level |
|-----------|-------|-------------------|------------|
| `app/schemas/` | 217 | 4 tests (validation) | Low |
| `app/core/auth.py` | 76 | 3 tests (mocked) | Medium |
| `app/core/errors.py` | 33 | 1 test | Low |
| `app/core/config.py` | 73 | 1 test (1 setting) | Low |
| `app/core/rate_limit.py` | 26 | **0 tests** | **High** — used in 5 endpoints |
| `app/services/agromonitoring_service.py` | 386 | 7 tests (mocked) | Medium |
| `app/services/ai_advisor_service.py` | 418 | 4 tests (pure fns only) | **High** — GeminiAIProvider untested |
| `app/services/scheduler.py` | 712 | **2 tests (partial)** | **Critical** — 32 fns untested |
| `app/services/chat_media_service.py` | 165 | 2 tests (sanitize only) | Medium |
| `app/services/mqtt_service.py` | 143 | **0 tests** | **High** — handles real sensor data |
| `app/api/fields.py` | 448 | 6 tests (via integration) | Medium |
| `app/api/chat.py` | 242 | 2 tests (via integration) | Medium |
| `app/api/sensors.py` | 78 | **1 test (partial)** | **High** — most endpoints untested |
| `app/api/satellite.py` | 60 | **0 tests** | Medium |
| `app/api/recommendations.py` | 102 | **0 tests** | **High** — AI + feedback untested |
| `app/api/session.py` | 27 | **0 tests** | Low |
| `app/main.py` | 158 | ~1 test (middleware only) | Medium |
| `app/database.py` | 27 | Indirect only | Low |

**Overall: ~20-25% of ~3,730 backend lines covered.**

---

## 4. Test Quality Assessment (F.I.R.S.T.)

### Fast ✓
All 25 unit tests run in milliseconds. The 10 integration tests take ~30s with real DB — acceptable.

### Independent (Isolated) ✗ — 3 Violations

| # | Violation | File | Details |
|---|-----------|------|---------|
| 1 | **Class-level state leaks** | `test_agromonitoring_free_first.py:116` | `_HTTPClient.calls`, `_last_args`, `_last_kwargs` are class variables shared across all 11 tests. Different execution orders corrupt results. |
| 2 | **Global singletons never reset** | Every test file | `rate_limiter`, `_circuit_open_until`, `_failure_count`, `_provider` (AI), `_storage` (media) persist across test runs. A test that triggers rate limiting or circuit breaker corrupts every subsequent test. |
| 3 | **No conftest.py** | `test_multitenant_integration.py` | `_make_user` and `_cleanup` duplicated across integration tests. No shared fixture to reset global state. |

### Repeatable (Deterministic) ✗ — 1 Critical Violation

| # | Violation | File | Details |
|---|-----------|------|---------|
| 1 | **ThreadPoolExecutor race condition** | `test_multitenant_integration.py:225` | `test_concurrent_five_field_limit` spawns 8 threads. Thread scheduling is non-deterministic. On a fast CI runner, advisory lock may not serialize as expected. **This test will flake.** |

### Self-Validating ✓
All tests use clear `assert` statements. No manual log inspection needed.

### Timely/Thorough ⚠️
- **Well tested:** Pydantic validation, AI safety rules, auth fail-closed, tenant isolation, cascading deletes, chat idempotency, image sanitization, AgroMonitoring retry logic
- **Untested:** Rate limiter (0 tests), MQTT service (0 tests), 32 scheduler functions (0 tests), GeminiAIProvider (0 tests), 18 API endpoints (0 tests), ~40 error paths (untested)

### Structural Quality

| Quality | Status | Details |
|---------|--------|---------|
| Tests behavior, not implementation | ✓ | All tests verify observable outcomes (HTTP codes, response bodies, DB state) |
| Readable (AAA pattern) | ✓ | Most tests follow clear Arrange-Act-Assert with helper functions reducing noise |
| Focused (single behavior per test) | ⚠️ | `test_concurrent_five_field_limit_delete_recreate_and_tenant_isolation` tests 5 behaviors in one function |

---

## 5. Critical Gaps

### Rate Limiter — Zero Coverage

File: `app/core/rate_limit.py` (26 lines). Used in 5 endpoints (field creation, chat, data refresh, AI refresh, sensor pairing). Needs 3-5 unit tests:
- Accept when under limit
- Reject with 429 when over limit
- Reset after window expires
- Different keys don't interfere

### Untested API Routers (18 Endpoints)

| Router | Endpoints | Priority |
|--------|-----------|----------|
| `sensors.py` | `GET /sensor-readings`, `GET /sensors/verify/{id}`, `POST /sensors/pair` | **High** — sensor data is core to the product |
| `recommendations.py` | `GET /recommendations`, `POST feedback`, `POST outcome`, `POST trigger-refresh` | **High** — AI recommendations are the main feature |
| `satellite.py` | `GET /satellite/latest`, `GET /ndvi`, `GET /truecolor` | Medium |
| `session.py` | `POST /bootstrap` | Low — simple query |
| `chat.py` | `GET /chat` (history), `GET /chat/attachments/{id}` | Medium |
| `fields.py` | `GET /fields` (list), `PATCH /fields/{id}`, `GET /weather-soil` | Medium |

### Untested Scheduler (32 Functions)

**Sync handlers** (need AgroMonitoring mock responses):
- `_sync_satellite`, `_sync_soil`, `_sync_weather`, `_sync_uvi`, `_sync_accumulations`

**AI analysis** (needs mocked Gemini client):
- `run_ai_for_field` (156 lines, 8 responsibilities — hardest function in the codebase)
- `run_ai_for_field_id`, `run_ai_by_field_id`, `ai_reasoning_loop`

**Deletion** (needs GCS/filesystem mock):
- `process_field_deletion_job`, `process_pending_field_deletions`

**Polygon management** (needs AgroMonitoring mock):
- `_register_polygon`, `_ensure_polygon`

### Untested AI Advisor (Core Logic)

| Function | Lines | What It Does |
|----------|-------|-------------|
| `GeminiAIProvider.recommendations()` | 57 | Calls Gemini with structured schema, retry, safety filter |
| `GeminiAIProvider.chat()` | ~40 | Calls Gemini with text + images, guard response |
| `VertexSearchKnowledgeProvider.retrieve()` | ~40 | Calls Google Discovery Engine |
| `_safe_context()` | ~15 | Truncates context for AI |
| `_approved_url()` | ~10 | Checks URL against approved prefixes |

### Untested MQTT Service

File: `app/services/mqtt_service.py` (143 lines). Zero tests despite handling real IoT sensor data ingestion.
- `on_message` — parses MQTT topic + JSON payload, validates, auto-discovers sensors, persists readings
- `_accept_device_message` — per-device sliding window rate limiter
- `on_connect` — MQTT subscription logic

---

## 6. Bugs Found in the Tests Themselves

| # | Bug | File | Severity |
|---|-----|------|----------|
| 1 | `_HTTPClient` uses class-level state (`calls`, `last_args`, `last_kwargs`) — leaks between tests | `test_agromonitoring_free_first.py:116-135` | **Fails Independence** |
| 2 | `ThreadPoolExecutor` with 8 workers racing for 5 slots — non-deterministic | `test_multitenant_integration.py:225` | **Fails Repeatability** |
| 3 | `test_oversized_payload` marked `@pytest.mark.integration` but never touches DB — always skipped in CI | `test_multitenant_integration.py:495` | **Fails CI Coverage** |
| 4 | `test_all_provider_intervals` hardcodes Settings defaults — breaks when config changes | `test_agromonitoring_free_first.py:87-95` | **Brittle** |
| 5 | No `conftest.py` — `_make_user` and `_cleanup` duplicated across integration tests | `test_multitenant_integration.py` | **Code Smell** |
| 6 | `test_concurrent_five_field_limit_delete_recreate_and_tenant_isolation` tests 5 behaviors in one function | `test_multitenant_integration.py:217-252` | **Not Focused** |

---

## 7. Backend Logic Bugs

| # | Bug | File | Severity |
|---|-----|------|----------|
| 1 | `database.py` defaults to `localhost`, `alembic.ini` defaults to `db` — migrations fail outside Docker | `database.py:6` vs `alembic.ini:4` | Medium |
| 2 | `sync_field_by_id` uses `asyncio.run()` — crashes if called from a running event loop (BackgroundTasks) | `scheduler.py:435-439` | **High** |
| 3 | `mqtt_service.on_message` does synchronous DB writes on MQTT network thread — blocks keep-alive | `mqtt_service.py:91-115` | **High** |
| 4 | `_ensure_polygon` exception handler re-queries stale field after `db.rollback()` — stale data may be committed | `scheduler.py:331-338` | Medium |
| 5 | `process_field_deletion_job` runs `asyncio.run(delete_polygon(...))` synchronously in BackgroundTasks | `scheduler.py:668` | Medium |
| 6 | Rate limiter is in-memory per-process — doesn't work across multiple API replicas | `rate_limit.py:26` | Low (solo dev) |
| 7 | `rate_limiter` instantiated at module import time — every test inherits stale state | `rate_limit.py:26` | **Fails Independence** |
| 8 | `_prepare_database` retries 5 times with 3s sleep, then crashes — `/health` endpoint has no retry | `main.py:64-72`, `main.py:149-158` | Low |
| 9 | `AgronomyKnowledgeDocument` model defined but never imported or used anywhere | `db_models.py:280-292` | Dead code |

### Broad `except Exception` Blocks (Hide Real Bugs)

| File | Line | Context |
|------|------|---------|
| `scheduler.py` | 331, 388, 438, 462, 614, 649 | Background workers — all errors logged but swallowed |
| `agromonitoring_service.py` | 49, 64, 87 | Cache and logging — failures silently ignored |
| `chat.py` | 235, 240 | Rollback handler — nested `except Exception: pass` |

---

## 8. Cross-System Bugs (iOS ↔ Backend)

| # | Bug | iOS File | Backend | Severity |
|---|-----|----------|---------|----------|
| 1 | `fetchSensors` uses `assignSensor` endpoint name for GET request — works but semantically wrong | `NetworkAgriDataRepository.swift:45` | `fields.py:187` and `fields.py:201` share same path | Code Smell |
| 2 | `fetchWeatherSoil` calls undocumented compat endpoint not in `APIConstants.Endpoints` | `NetworkAgriDataRepository.swift:130` | `fields.py:437` (`include_in_schema=False`) | Medium |
| 3 | Base URL hardcoded to `localhost:8000` — physical devices silently fail all API calls | `APIConstants.swift:5` | — | **High** (physical device testing) |
| 4 | Chat path `api/fields/{id}/chat` — verified matches backend router prefix | `APIConstants.swift:19` | `chat.py:21` | OK ✓ |

---

## 9. iOS App Bug Summary (37 Issues)

| Category | Count | Key Examples |
|----------|-------|-------------|
| **Crash** | 4 | Force-unwrap URL (`APIConstants.swift:5`), force-cast map view (`FieldSelectionView.swift:467`), array index-out-of-bounds (`MockAgriDataRepository.swift:134`), nil UIImage annotation (`FieldSelectionView.swift:503`) |
| **Data Loss/Flow** | 6 | Background polling continues briefly (`DashboardView.swift:166`), idempotency key reset too aggressively (`AIChatViewModel.swift:9`), `AlertsBottomSheet` loses scroll state on field change (`DashboardView.swift:94`), toasts overwrite each other (`DashboardView.swift:177`), clearFieldData doesn't cancel in-flight requests (`DashboardViewModel.swift:145`) |
| **API Mismatch** | 3 | `weather-soil` not in constants, `fetchSensors` uses POST name for GET, satellite path hardcoded |
| **Visual Bug** | 6 | Moisture chart has 1 data point (invisible) (`DashboardView.swift:646`), hardcoded Lahore default location (`FieldSelectionViewModel.swift:37`), pH gauge defaults to 4 when nil (`DashboardView.swift:700`), typo "Lets" (`AddFieldIntroView.swift:127`), `matchedGeometryEffect` ID collision (`AuthTabToggle.swift:48/75`), SF Symbol fallback aspect mismatch (`DashboardView.swift:530`) |
| **Code Smell** | 18 | MVVM leak (`fieldSessionStore` exposed), dead code (`AIAdvisorCard.swift`), snake_case properties without CodingKeys, hybrid Combine+async architecture, magic strings for UserDefaults keys |

---

## 10. ESP32 Firmware Bugs

| # | Bug | File | Severity |
|---|-----|------|----------|
| 1 | Hardcoded `DEVICE_ID = "ESP32_FIELD_NODE_1"` — multiple units collide on MQTT, DB overwrites | `main.cpp:7` | **P1** |
| 2 | `delay(30000)` blocks main loop — prevents future interrupt-driven logic, blocks MQTT | `main.cpp:63` | **P1** |
| 3 | `map()` returns `long`, assigned to `float` — loses fractional precision | `main.cpp:44` | Low |

---

## 11. Implementation Roadmap (CI Readiness)

### Step 1: `conftest.py` — Fix Independence (15 min)

Create `AgriVision-Backend/tests/conftest.py` with:
- `autouse` fixture resetting ALL global singletons before every test (`_circuit_open_until`, `_failure_count`, `_inflight`, `rate_limiter._events`, `_provider`, `_storage`)
- Shared `test_user` and `db_session` fixtures (move from `test_multitenant_integration.py`)

**Impact: Fixes the #1 independence violation.**

### Step 2: Fix `_HTTPClient` — Fix Independence (20 min)

Replace class-level `_HTTPClient` mock in `test_agromonitoring_free_first.py:116-135` with instance-level `AsyncMock` or a per-test fixture factory.

**Impact: Removes state leakage across 11 agromonitoring tests.**

### Step 3: Fix Flaky ThreadPoolExecutor — Fix Repeatability (10 min)

Replace `ThreadPoolExecutor` in `test_multitenant_integration.py:225` with sequential calls. The advisory lock already serializes — threading adds no value, just flakiness.

**Impact: Makes concurrent field limit test deterministic.**

### Step 4: Move `test_oversized_payload` — Fix CI Coverage (5 min)

Remove `@pytest.mark.integration` from `test_oversized_payload_and_untrusted_request_id_are_handled_safely` (`test_multitenant_integration.py:495`). Move to `test_validation_and_errors.py`.

**Impact: Runs in every CI run, catches middleware issues in seconds.**

### Step 5: Split Multi-Behavior Test — Fix Focused (15 min)

Split `test_concurrent_five_field_limit_delete_recreate_and_tenant_isolation` into 3 focused tests:
1. `test_field_limit_enforces_max_five_active_fields`
2. `test_field_delete_and_recreate_restores_slot`
3. `test_legacy_harvest_endpoint_returns_410`

**Impact: Better failure diagnosis.**

### Step 6: Add Rate Limiter Tests — Fill Critical Gap (30 min)

Create `tests/test_rate_limit.py` with 3-5 unit tests:
- Accept when under limit
- Reject with 429 when over limit
- Different keys don't interfere
- Window expiry resets counter

**Impact: Fills critical coverage gap for a component used in 5 endpoints.**

### Step 7: Delete Brittle Config Test (2 min)

Delete `test_all_provider_intervals_and_worker_scan_match_timeline` (`test_agromonitoring_free_first.py:87-95`).

**Impact: Removes false failures when Settings defaults change.**

---

### Order Summary

| Step | What | Time | Impact |
|------|------|------|--------|
| 1 | `conftest.py` with global state reset | 15min | **Fixes Independence** |
| 2 | Fix `_HTTPClient` class state | 20min | **Fixes Independence** |
| 3 | Remove `ThreadPoolExecutor` | 10min | **Fixes Repeatability** |
| 4 | Move `test_oversized_payload` | 5min | Runs in CI, was skipped |
| 5 | Split multi-behavior test | 15min | Better failure diagnosis |
| 6 | Rate limiter unit tests | 30min | Fills critical gap |
| 7 | Delete brittle config test | 2min | Removes false failures |

**Total: ~1.5 hours**

---

## 12. High-Risk Code Locations

Functions that are hard to test and likely to hide bugs:

| Function | File | Lines | Risk | Why |
|----------|------|-------|------|-----|
| `run_ai_for_field` | `scheduler.py` | 156 | **Critical** | 8 responsibilities, 7 exception handlers, global state |
| `post_message` | `chat.py` | 126 | **High** | Mixes DB + AI + filesystem + rate limiter |
| `_request` / `perform` | `agromonitoring_service.py` | 93+52 | **High** | Nested retry + circuit breaker + cache — inner fn not independently testable |
| `get_current_user` | `auth.py` | 58 | **High** | Does auth + user provisioning + email sync in one fn |
| `create_field` | `fields.py` | 64 | **Medium** | Rate limit + DB + AgroMonitoring API + background tasks |
| `on_message` | `mqtt_service.py` | 73 | **High** | Synchronous DB writes on MQTT thread |
| `_sync_satellite` | `scheduler.py` | 50 | **Medium** | Scene search + stats + caching + NDVI update |
| `get_dashboard` | `fields.py` | 95 | **Medium** | 5 data sources combined with complex branching |

### Global State That Leaks Between Tests

| Module | Variable | Type | Reset Needed? |
|--------|----------|------|---------------|
| `agromonitoring_service` | `_circuit_open_until` | `float` | Yes — persists across tests |
| `agromonitoring_service` | `_failure_count` | `int` | Yes — accumulates across tests |
| `agromonitoring_service` | `_inflight` / `_inflight_lock` | `dict` / `Lock` | Yes — singleflight state |
| `agromonitoring_service` | `_semaphore` | `asyncio.Semaphore` | Yes — concurrency state |
| `ai_advisor_service` | `_provider` | `AIProvider \| None` | Yes — singleton pattern |
| `chat_media_service` | `_storage` | `PrivateMediaStorage \| None` | Yes — singleton pattern |
| `rate_limit` | `rate_limiter` | `InMemoryRateLimiter` | Yes — instantiated at import time |
| `mqtt_service` | `_device_events` | `dict` | Yes — rate-limit state |

---

## 13. Test Execution Quick Reference

```bash
# Run unit tests only (fast, no Docker)
pytest -m "not integration" -x -v

# Run integration tests only (needs Docker PostgreSQL + PostGIS)
pytest -m integration -x -v

# Run all tests
pytest -x -v

# Run with coverage
pytest --cov=app -m "not integration"
```

### Environment Requirements
- **Unit tests**: Python 3.11+, dependencies from `requirements.txt`
- **Integration tests**: Docker running with PostgreSQL + PostGIS (`db` service in `docker-compose.yml`)

---

## 14. Session Handoff Notes

### If Starting a New Session With Fresh Context
1. Read this file first for the full test landscape and all known bugs
2. Read `Docs/architectural_and_technical_review.md` for the original audit (note: it's **stale** — see section 15)
3. Run `pytest -v` to see current test status
4. Implement steps from the Implementation Roadmap (section 11)

### Quick Wins (ordered by impact)
1. Rate limiter unit tests (30 min)
2. `conftest.py` with global state reset (15 min)
3. Fix `_HTTPClient` class state (20 min)
4. Move `test_oversized_payload` out of integration marker (5 min)
5. Remove `ThreadPoolExecutor` from concurrent field test (10 min)

### Known Issues
- `test_concurrent_five_field_limit_delete_recreate_and_tenant_isolation` is flaky due to `ThreadPoolExecutor`
- `_HTTPClient` in `test_agromonitoring_free_first.py` leaks state between test functions
- Integration tests require manual Docker setup — not CI-ready without Docker in the runner
- The `docker-compose.yml` exposes 6 services but only `db` (PostgreSQL+PostGIS) is needed for tests

---

## 15. Stale Documentation Note

The document `Docs/architectural_and_technical_review.md` describes two P0 bugs that are **already fixed in the current code**:

| Alleged P0 Bug | Current Status |
|----------------|----------------|
| **Async session closure** in `recommendations.py` | Fixed. All background tasks (`run_ai_by_field_id`, `_run_ai_background`, `_sync_field_background`) create their own `SessionLocal()` instead of borrowing the request-scoped session. |
| **Unsigned JWT bypass** in `auth.py` | Fixed. The `jwt.decode(token, options={"verify_signature": False})` fallback is gone. Current code properly raises `APIError(503)` when Firebase is unavailable. |

Do not treat these as active gaps. The review doc's remaining P1/P2 findings (hardcoded Dashboard values, MQTT device ID, blocking delay) are still valid and listed in sections 9-10 of this document.
