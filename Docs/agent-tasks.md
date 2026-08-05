# AgriVision — AI Agent Task Queue

Divide-and-conquer document. Each task is small enough for one AI agent session. Give tasks to agents in any order (they are independent). Mark `[x]` when done.

---

## How to use this document

1. Pick a task from the list below
2. Give the agent the task description + the relevant file paths
3. Agent writes the code
4. Run the verification command
5. Mark `[x]` and move to the next task

---

## Task 1: Create `conftest.py` with Global State Reset `[x]`

**Files to create:** `AgriVision-Backend/tests/conftest.py`

**What to do:**
Create a pytest `conftest.py` in the tests directory with:

1. An `autouse` fixture that runs before every single test and resets ALL global singleton state:

```python
# Must reset these before each test:
# agromonitoring_service._circuit_open_until  (set to 0.0)
# agromonitoring_service._failure_count       (set to 0)
# agromonitoring_service._inflight            (clear the dict)
# rate_limit.rate_limiter._events             (clear the dict)
# ai_advisor_service._provider                (set to None)
# chat_media_service._storage                 (set to None)
```

2. Import the modules using `import app.services.agromonitoring_service as agro` style inside the fixture to avoid circular imports at module load time.

3. A `pytest.fixture` called `test_user` that:
   - Creates a `User` in the database with a unique `firebase_uid`
   - Yields the user
   - Cleans up after the test

4. A `pytest.fixture` called `db_session` that provides a clean `SessionLocal()` and closes it after the test.

**Verification:**
```bash
cd AgriVision-Backend
# Run tests twice — if any test depends on state from a previous run, it will show now
pytest -x -m "not integration" -v
pytest -x -m "not integration" -v  # Run again, should give same results
```

**Do NOT:** Modify any existing test files. This is purely additive.

---

## Task 2: Fix `_HTTPClient` Class State Leak `[x]`

**Files to edit:** `AgriVision-Backend/tests/test_agromonitoring_free_first.py`

**What to do:**
The `_HTTPClient` helper class (around line 116-135) uses class-level variables (`calls`, `last_args`, `last_kwargs`) that leak state between tests.

Replace the entire `_HTTPClient` class with a pytest fixture that returns fresh mocks per test:

1. Remove the `_HTTPClient` class entirely
2. Create a fixture `mock_http_client` that patches `agromonitoring_service.httpx.AsyncClient` with a fresh `AsyncMock` for each test
3. The fixture should configure the mock's `__aenter__.return_value.request` to return a default `httpx.Response(200, json={"ok": True})` that each test can override
4. Update the tests that currently use `_HTTPClient` to use the fixture instead:
   - `test_provider_absolute_urls_keep_api_key_query_string`
   - `test_no_content_delete_is_successful_without_json_decode_retry`
   - `test_entitlement_denial_is_non_retryable_and_not_retried`
   - `test_bad_provider_request_is_not_retried`

**Verification:**
```bash
cd AgriVision-Backend
pytest tests/test_agromonitoring_free_first.py -x -v
# All 11 tests should pass
```

**Do NOT:** Change the test logic or assertions. Only change how mocks are created.

---

## Task 3: Remove Flaky `ThreadPoolExecutor` from Field Limit Test `[x]`

**Files to edit:** `AgriVision-Backend/tests/test_multitenant_integration.py`

**What to do:**
In the function `test_concurrent_five_field_limit_delete_recreate_and_tenant_isolation` (around line 217-252):

1. Replace the `ThreadPoolExecutor` with sequential `client.post()` calls in a loop
2. Assert that the first 5 return 201, and the next 3 return 409 (or whatever combination naturally occurs with sequential calls)
3. Remove the `from concurrent.futures import ThreadPoolExecutor` import if it's no longer used

**Why:** The advisory lock already serializes DB writes. Threading adds no value, just non-deterministic ordering.

**Verification:**
```bash
cd AgriVision-Backend
pytest tests/test_multitenant_integration.py::test_concurrent_five_field_limit_delete_recreate_and_tenant_isolation -x -v
# Requires Docker PostgreSQL running
```

**Do NOT:** Change any other tests in the file. Do NOT change the asserts for tenant isolation, 410 endpoint, or delete behavior — only the concurrent creation part.

---

## Task 4: Move `test_oversized_payload` from Integration to Unit `[x]`

**Files to edit:**
- `AgriVision-Backend/tests/test_multitenant_integration.py`
- `AgriVision-Backend/tests/test_validation_and_errors.py`

**What to do:**
The test `test_oversized_payload_and_untrusted_request_id_are_handled_safely` at line 495 in the integration file only tests FastAPI middleware — it never touches the database.

1. Remove `@pytest.mark.integration` from the test
2. Remove the test function from `test_multitenant_integration.py`
3. Add it to `test_validation_and_errors.py` (keeping the exact same test logic)
4. At the bottom of `test_multitenant_integration.py`, remove the unused imports that were only needed by this test (check what's left over). The imports `io` and `PIL.Image` might still be needed by the chat test — check before removing.

**Verification:**
```bash
cd AgriVision-Backend
# Should run without Docker
pytest tests/test_validation_and_errors.py -x -v -k "oversized"
```

**Do NOT:** Change the test logic. Only move it.

---

## Task 5: Delete Brittle Config Test `[x]`

**Files to edit:** `AgriVision-Backend/tests/test_agromonitoring_free_first.py`

**What to do:**
Delete the function `test_all_provider_intervals_and_worker_scan_match_timeline` (around line 87-95).

This test hardcodes expected values of `Settings` defaults. Changing a default in `config.py` breaks the test for no behavioral reason. It provides zero value.

**Verification:**
```bash
cd AgriVision-Backend
pytest tests/test_agromonitoring_free_first.py -x -v
# Should show 10 tests instead of 11 (one removed)
# All should pass
```

**Do NOT:** Remove any other test.

---

## Task 6: Add Rate Limiter Unit Tests `[x]`

**Files to create:** `AgriVision-Backend/tests/test_rate_limit.py`

**What to do:**
Write 5 focused unit tests for `app/core/rate_limit.py`. No database, no mocks needed — pure logic.

Tests to write:

1. `test_accepts_request_under_limit` — Check 3 times with limit=5, window=60. No exception raised.

2. `test_rejects_request_over_limit` — Check 6 times with limit=5, window=60. The 6th call raises `APIError(429, "rate_limited", ...)`.

3. `test_different_keys_dont_interfere` — Check "key-a" 5 times (should pass), then check "key-b" 5 times (should also pass). Verify neither affects the other.

4. `test_window_expiry_resets_counter` — Check 5 times to reach limit, then mock `time.monotonic` to advance by 61 seconds, check again — should pass.

5. `test_retryable_flag_is_set` — When rate limited, the error must have `retryable=True`.

Use `unittest.mock.patch` for `time.monotonic` in the window expiry test.

**Verification:**
```bash
cd AgriVision-Backend
pytest tests/test_rate_limit.py -x -v
# All 5 tests pass in < 100ms
```

**Do NOT:** Modify any existing files.

---

## Task 7: Add Unit Tests for Sensor Endpoints (Pair, Verify, Readings) `[x]`

**Files to create:** `AgriVision-Backend/tests/test_sensors.py`

**What to do:**
Write focused tests for `app/api/sensors.py` endpoints. These are **unit tests** — mock the database, do not require PostgreSQL.

For each test, use `unittest.mock.Mock` or `unittest.mock.MagicMock` for the database session and the `get_current_user` dependency.

1. **Test `GET /api/fields/{id}/sensor-readings`**
   - Mock `owned_field` to return a field
   - Mock `db.query(Sensor.id)` to return sensor IDs
   - Mock `db.query(SensorReading)` to return a list of readings
   - Verify it returns the readings

2. **Test `GET /api/fields/{id}/sensor-readings` with no sensors**
   - Same setup but `db.query(Sensor.id)` returns empty list
   - Verify it returns empty list

3. **Test `GET /api/sensors/verify/{device_id}` with valid online sensor**
   - Mock `db.query(Sensor)` to return a sensor with `last_seen` within 60 min
   - Verify response has `is_verified: True`

4. **Test `GET /api/sensors/verify/{device_id}` with unowned sensor**
   - Mock sensor with `owner_id` different from current user
   - Verify it raises `APIError(409)`

5. **Test `GET /api/sensors/verify/{device_id}` with invalid device_id (too long)**
   - Pass a 101-character device_id
   - Verify it raises `APIError(422)`

6. **Test `POST /api/sensors/pair` with online unowned sensor**
   - Mock rate limiter to accept
   - Mock sensor query to return unowned sensor with recent last_seen
   - Verify returns `SensorPairResponse` with `is_paired: True`

7. **Test `POST /api/sensors/pair` with sensor owned by another tenant**
   - Mock sensor with `owner_id` that doesn't match
   - Verify raises `APIError(409)`

8. **Test `POST /api/sensors/pair` with offline sensor**
   - Mock sensor with `last_seen` older than 60 min
   - Verify raises `APIError(409, "sensor_not_online")`

**Verification:**
```bash
cd AgriVision-Backend
pytest tests/test_sensors.py -x -v
# All 8 tests pass in < 200ms, no Docker needed
```

**Do NOT:** Modify any existing files.

---

## Task 8: Add Unit Tests for Satellite Endpoints `[x]`

**Files to create:** `AgriVision-Backend/tests/test_satellite.py`

**What to do:**
Write focused tests for `app/api/satellite.py`. Unit tests with mocked DB.

1. **Test `GET /api/fields/{id}/satellite/latest` with existing scene**
   - Mock `owned_field` and `_latest_scene` to return a `SatelliteScene`
   - Verify response contains expected fields (id, acquired_at, statistics, urls)

2. **Test `GET /api/fields/{id}/satellite/latest` with no scene**
   - Mock `_latest_scene` to raise `APIError(404)`
   - Verify endpoint returns 404

3. **Test `GET /api/fields/{id}/satellite/latest/ndvi` with valid image**
   - Mock `_latest_scene` with `ndvi_image_path` set
   - Mock `FileResponse` path validation
   - Verify response is a `FileResponse`

4. **Test `GET /api/fields/{id}/satellite/latest/truecolor` with valid image**
   - Same as above but with `truecolor_image_path`

5. **Test `GET /api/fields/{id}/satellite/latest/ndvi` with missing image**
   - Mock `_latest_scene` with `ndvi_image_path = None`
   - Verify returns 404

**Verification:**
```bash
cd AgriVision-Backend
pytest tests/test_satellite.py -x -v
# All 5 tests pass
```

**Do NOT:** Modify any existing files.

---

## Task 9: Add Unit Tests for Recommendation Endpoints `[x]`

**Files to create:** `AgriVision-Backend/tests/test_recommendations.py`

**What to do:**
Write focused tests for `app/api/recommendations.py`. Unit tests with mocked DB.

1. **Test `GET /api/fields/{id}/recommendations`**
   - Mock `db.query(FieldRecommendation)` to return list
   - Verify response is the expected list

2. **Test `POST /api/recommendations/{id}/feedback` with valid status**
   - Mock recommendation query to return a recommendation
   - Set status to "implemented"
   - Verify response has updated status

3. **Test `POST /api/recommendations/{id}/feedback` with nonexistent recommendation**
   - Mock query to return None
   - Verify raises `APIError(404)`

4. **Test `POST /api/recommendations/{id}/outcome` with valid implemented recommendation**
   - Mock recommendation with `status == "implemented"`
   - Post `{"outcome": "useful", "notes": "Helped"}`
   - Verify response has outcome set

5. **Test `POST /api/recommendations/{id}/outcome` with pending recommendation**
   - Mock recommendation with `status == "pending"`
   - Verify raises `APIError(409, "recommendation_not_implemented")`

6. **Test `POST /api/fields/{id}/recommendations` (trigger AI refresh)**
   - Mock `owned_field` to return field
   - Mock `rate_limiter.check` to pass
   - Verify returns `202` with `"status": "accepted"`

**Verification:**
```bash
cd AgriVision-Backend
pytest tests/test_recommendations.py -x -v
# All 6 tests pass
```

**Do NOT:** Modify any existing files.

---

## Task 10: Add Unit Tests for Session Bootstrap Endpoint `[x]`

**Files to create:** `AgriVision-Backend/tests/test_session.py`

**What to do:**
Write tests for `app/api/session.py`. Unit tests with mocked DB.

1. **Test `POST /api/session/bootstrap` returns user info and fields**
   - Mock `db.query(Field)` to return 2 fields
   - Verify response includes user, fields list, `active_field_limit`, `active_field_count`

2. **Test `POST /api/session/bootstrap` with zero fields**
   - Mock fields query to return empty list
   - Verify `active_field_count == 0`

**Verification:**
```bash
cd AgriVision-Backend
pytest tests/test_session.py -x -v
# Both tests pass
```

**Do NOT:** Modify any existing files.

---

## Task 11: Add Unit Tests for Chat History and Attachment Endpoints `[x]`

**Files to create:** `AgriVision-Backend/tests/test_chat_history.py`

**What to do:**
The `POST /chat` endpoint is already tested via integration tests. These tests cover the **read endpoints** which are untested:

1. **Test `GET /api/fields/{id}/chat` returns paginated history**
   - Mock `db.query(AIChatMessage)` to return messages
   - Verify response is a list of `ChatMessageResponse`

2. **Test `GET /api/fields/{id}/chat` with `before` parameter**
   - Mock query with `before` filter
   - Verify query is filtered correctly

3. **Test `GET /api/fields/{id}/chat/attachments/{id}` with valid attachment**
   - Mock `db.query(ChatAttachment)` to return an attachment
   - Mock `get_chat_media_storage().read()` to return bytes
   - Verify response is `Response` with correct mime_type

4. **Test `GET /api/fields/{id}/chat/attachments/{id}` with nonexistent attachment**
   - Mock query to return None
   - Verify raises `APIError(404)`

**Verification:**
```bash
cd AgriVision-Backend
pytest tests/test_chat_history.py -x -v
# All 4 tests pass
```

**Do NOT:** Modify any existing files.

---

## Task 12: Add Unit Tests for Field List, Update, and Delete Endpoints `[x]`

**Files to create:** `AgriVision-Backend/tests/test_fields_basic.py`

**What to do:**
The field creation and dashboard endpoints are tested via integration tests. These cover the remaining **untested field endpoints**:

1. **Test `GET /api/fields` returns list of fields**
   - Mock `db.query(Field)` with filters for owner_id and status
   - Verify returns list of `FieldResponse`

2. **Test `GET /api/fields` with `include_archived=true`**
   - Verify archived fields are included in query

3. **Test `PATCH /api/fields/{id}` updates field name**
   - Mock `owned_field` to return field
   - Send update with new name
   - Verify field name changed

4. **Test `PATCH /api/fields/{id}` with invalid harvest date**
   - Set plantation_date to earlier than expected_harvest_date
   - Verify raises `APIError(422, "invalid_harvest_date")`

5. **Test `POST /api/fields/{id}/data-refresh` with API key configured**
   - Mock settings to have API key
   - Mock `owned_field` to return field
   - Mock `rate_limiter.check` to pass
   - Verify returns 202

6. **Test `POST /api/fields/{id}/data-refresh` without API key**
   - Mock settings to have empty API key
   - Verify raises `APIError(503, "agromonitoring_not_configured")`

**Verification:**
```bash
cd AgriVision-Backend
pytest tests/test_fields_basic.py -x -v
# All 6 tests pass
```

**Do NOT:** Modify any existing files.

---

## Task 13: Add Unit Tests for AgroMonitoring Service (Remaining Functions) `[x]`

**Files to create:** `AgriVision-Backend/tests/test_agromonitoring_extended.py`

**What to do:**
The existing `test_agromonitoring_free_first.py` covers 7 of ~15 public functions. These tests cover the remaining untested functions:

1. **Test `get_soil_data` correct conversion from Kelvin to Celsius**
   - Mock `_request` to return `{"moisture": 0.3, "t0": 300.15, "t10": 295.15, "dt": 1000}`
   - Verify returns `surface_temp_c = 27.0`, `depth_temp_c = 22.0`

2. **Test `get_weather_forecast` with missing optional fields**
   - Mock current without `main` or `weather`
   - Mock forecast as empty list
   - Verify returns safe defaults (None temps, empty forecast_days)

3. **Test `get_current_uvi` returns expected shape**
   - Mock `_request` to return `{"uvi": 5.2}`
   - Verify returns correctly

4. **Test `get_forecast_uvi` returns list**
   - Mock `_request` to return `[{"uvi": 3.0}, {"uvi": 4.0}]`
   - Verify returns list

5. **Test `get_index_statistics` with missing stats**
   - Mock scene dict without `stats` key
   - Verify returns None

6. **Test `get_index_statistics` with non-dict result**
   - Mock `_request` to return `[1, 2, 3]` (list instead of dict)
   - Verify returns None

7. **Test `create_polygon` fallback on 400**
   - Mock `_request` to raise `AgroAPIError` with status_code=400 on first call, then return list with matching polygon on second call
   - Verify returns the existing polygon ID

8. **Test `search_latest_scene` with no eligible Sentinel images**
   - Mock `_request` to return images with non-Sentinel types
   - Verify returns None

9. **Test `_singleflight` with exception in task**
   - Call `_singleflight` with a factory that raises
   - Call again with same key — should retry (not return cached exception)
   - Verify the task is cleaned up from `_inflight`

**Verification:**
```bash
cd AgriVision-Backend
pytest tests/test_agromonitoring_extended.py -x -v
# All 9 tests pass
```

**Do NOT:** Modify any existing files.

---

## Task 14: Add Unit Tests for AI Advisor Safety Functions (Edge Cases) `[x]`

**Files to create:** `AgriVision-Backend/tests/test_ai_advisor_extended.py`

**What to do:**
The existing `test_validation_and_errors.py` covers basic cases of `_apply_safety_policy`, `_guard_chat_response`, `_canonical_category`, and `_recommendation_payload`. These tests cover the **edge cases**:

1. **Test `_apply_safety_policy` with empty advice (returns None)**
   - Pass item with `advice=""`
   - Verify returns None

2. **Test `_apply_safety_policy` with string confidence**
   - Pass `confidence="invalid"`
   - Verify defaults to 0.4

3. **Test `_apply_safety_policy` with out-of-range confidence**
   - Pass `confidence=2.0`
   - Verify clamped to 1.0

4. **Test `_apply_safety_policy` with invalid priority**
   - Pass `priority="urgent"` (not in low/medium/high)
   - Verify defaults to "medium"

5. **Test `_apply_safety_policy` with unknown URL (filtered out)**
   - Pass `evidence_urls=["https://evil.com/hack"]`
   - Verify evidence list is empty

6. **Test `_guard_chat_response` with risky advice + supporting URL in text**
   - Pass text containing "spray" + URL in both text and approved_evidence
   - Verify passes through (not blocked)

7. **Test `_guard_chat_response` with response already starting with visual disclaimer**
   - Pass text starting with "This is a visual assessment"
   - Verify no duplicate prefix added

8. **Test `_recommendation_payload` with raw text containing JSON (no code fence)**
   - Pass response with `parsed=None`, `text` containing `{"recommendations": [...]}`
   - Verify extracts correctly

9. **Test `_recommendation_payload` with no valid JSON**
   - Pass response with `parsed=None`, `text="Hello world"`
   - Verify raises `ValueError`

10. **Test `_canonical_category` with all 7 predefined categories**
    - Pass each of the 7 valid categories
    - Verify they return unchanged (identity mapping)

**Verification:**
```bash
cd AgriVision-Backend
pytest tests/test_ai_advisor_extended.py -x -v
# All 10 tests pass
```

**Do NOT:** Modify any existing files.

---

## Task 15: Add Unit Tests for MQTT Service `[x]`

**Files to create:** `AgriVision-Backend/tests/test_mqtt.py`

**What to do:**
Write focused tests for `app/services/mqtt_service.py`. These test the parsing and validation logic — NOT the MQTT network connection:

1. **Test `_accept_device_message` with under limit**
   - Call 50 times with limit=120, window=60
   - Verify returns True each time

2. **Test `_accept_device_message` when over limit**
   - Call 121 times with limit=120, window=60
   - Verify the 121st call returns False

3. **Test `_accept_device_message` window expiry**
   - Call 120 times to reach limit
   - Mock `time.monotonic` to advance by 61 seconds
   - Verify next call returns True (counter reset)

4. **Test `on_message` with valid JSON payload**
   - Create a mock MQTT message with topic `agrivision/sensors/test_device_1/readings` and payload `{"temperature": 25.5, "moisture": 60.0}`
   - Mock `SessionLocal` and `db.query(Sensor)` to return None (auto-discover)
   - Verify `Sensor` is created, `SensorReading` is saved, `last_seen` is updated

5. **Test `on_message` with invalid topic format**
   - Create message with topic `wrong/topic/format`
   - Verify no DB operations are performed

6. **Test `on_message` with payload exceeding 16KB**
   - Create payload of 20KB
   - Verify message is rejected

7. **Test `on_message` with unsupported fields in payload**
   - Payload includes `{"temperature": 25, "secret_field": "hack"}`
   - Verify message is rejected (unsupported fields detected)

8. **Test `on_message` with value outside accepted range**
   - Payload includes `{"temperature": 99999}`
   - Verify message is rejected (value > 10000)

**Verification:**
```bash
cd AgriVision-Backend
pytest tests/test_mqtt.py -x -v
# All 8 tests pass
```

**Do NOT:** Modify any existing files.

---

## Task 16: Split Multi-Behavior Integration Test `[x]`

**Files to edit:** `AgriVision-Backend/tests/test_multitenant_integration.py`

**What to do:**
The function `test_concurrent_five_field_limit_delete_recreate_and_tenant_isolation` tests 5 different behaviors. Split into 3 focused test functions:

1. **Create `test_field_limit_enforces_max_five_active_fields`**
   - Create 5 fields → all succeed
   - Create 6th → 409 with `active_field_limit`
   - Delete a field → 204
   - Create replacement → 201

2. **Create `test_field_delete_and_recreate_restores_slot`**
   - Create 1 field
   - Delete it
   - Verify `GET /api/fields/{id}` returns 404

3. **Create `test_legacy_harvest_endpoint_returns_410`**
   - Create 1 field
   - POST to `/api/fields/{id}/harvest`
   - Verify 410 with `field_archiving_removed`

Each test should set up its own data and clean up afterward. The original test function should be removed after splitting.

**Verification:**
```bash
cd AgriVision-Backend
pytest tests/test_multitenant_integration.py -x -v -k "field_limit or harvest or recreate"
# Requires Docker PostgreSQL
# All 3 new tests pass
```

**Do NOT:** Change any other tests in the file.

---

## Task 17: Add Unit Tests for Scheduler Sync Handlers `[x]`

**Files to create:** `AgriVision-Backend/tests/test_scheduler_sync.py`

**What to do:**
Write focused tests for the scheduler sync handlers in `app/services/scheduler.py`. Mock the AgroMonitoring service calls. Use a real SQLite or mocked PostgreSQL session.

These tests create a `Field` record in a real database session (using the test DB or SQLite):

1. **Test `_sync_satellite` with new scene**
   - Create a field with `agromonitory_poly_id` set
   - Mock `search_latest_scene` to return a valid scene dict
   - Mock `get_index_statistics` to return stats for ndvi, evi, evi2
   - Mock `cache_scene_image` to return paths
   - Call `_sync_satellite`
   - Verify `SatelliteScene` is created, field `latest_ndvi` is set, `agro_status` is "available"

2. **Test `_sync_satellite` with duplicate scene**
   - Same setup but mock `search_latest_scene` to return same scene as existing
   - Create `SatelliteScene` with matching `provider_scene_id` first
   - Call `_sync_satellite`
   - Verify no duplicate scene created (field.agro_status = "available")

3. **Test `_sync_satellite` with no scene available**
   - Mock `search_latest_scene` to return None
   - Call `_sync_satellite`
   - Verify field.agro_status = "pending", field.agro_error set

4. **Test `_sync_soil` with valid data**
   - Mock `get_soil_data` to return moisture + temperature data
   - Call `_sync_soil`
   - Verify `FieldObservation` created with metric "soil_current"

5. **Test `_sync_weather` with valid data**
   - Mock `_centroid` to return lat/lon
   - Mock `get_weather_forecast` to return forecast dict
   - Call `_sync_weather`
   - Verify `FieldObservation` created

6. **Test `_sync_uvi` with entitlement error on forecast**
   - Mock `get_current_uvi` to return valid
   - Mock `get_forecast_uvi` to raise `AgroEntitlementError`
   - Call `_sync_uvi`
   - Verify `ProviderCapability` for `uvi_forecast` has status "unsupported"

**Verification:**
```bash
cd AgriVision-Backend
pytest tests/test_scheduler_sync.py -x -v
# Requires Docker PostgreSQL for real DB session
# All 6 tests pass
```

**Do NOT:** Modify any existing files.

---

## Task 18: Add Unit Tests for AI Analysis Run (Scheduler AI Core) `[x]`

**Files to create:** `AgriVision-Backend/tests/test_scheduler_ai.py`

**What to do:**
Write tests for `run_ai_for_field` — the core AI analysis logic in the scheduler. This is the hardest function in the codebase (156 lines, 8 responsibilities).

Mock the `GeminiAIProvider` so no real AI calls are made:

1. **Test AI run creates recommendations when context is fresh**
   - Create a field with observations and sensors
   - Mock `get_ai_provider` to return a mock that returns 2 recommendations
   - Call `run_ai_for_field`
   - Verify `AIAnalysisRun` created with status "completed"
   - Verify 2 `FieldRecommendation` records created

2. **Test AI run skips when duplicate context fingerprint exists**
   - Same setup but create an `AIAnalysisRun` with matching fingerprint first
   - Call `run_ai_for_field`
   - Verify no new `AIAnalysisRun` created (duplicate detection works)

3. **Test AI run marks stale runs as failed**
   - Create an `AIAnalysisRun` with status "running" and old `started_at`
   - Call `run_ai_for_field`
   - Verify old run is marked "failed"

4. **Test AI run handles provider failure gracefully**
   - Mock `get_ai_provider` to raise `APIError(503)`
   - Call `run_ai_for_field`
   - Verify `AIAnalysisRun` has status "failed" with error message

5. **Test AI run with insufficient data quality**
   - Create a field with no observations and no sensors
   - Mock `get_ai_provider` to return 1 recommendation
   - Call `run_ai_for_field`
   - Verify recommendation has advice overridden with "More field evidence is needed..."

**Verification:**
```bash
cd AgriVision-Backend
pytest tests/test_scheduler_ai.py -x -v
# Requires Docker PostgreSQL
# All 5 tests pass
```

**Do NOT:** Modify any existing files.

---

## Task 19: Add Unit Tests for Local Media Storage

**Files to create:** `AgriVision-Backend/tests/test_media_storage.py`

**What to do:**
Write tests for `app/services/chat_media_service.py` — specifically the `LocalPrivateMediaStorage` class. Use `tempfile` for isolated filesystem testing:

1. **Test `put` and `read` round-trip**
   - Create `LocalPrivateMediaStorage` with temp directory
   - Create a `SanitizedImage`
   - Call `put` → get key
   - Call `read(key)` → get bytes back
   - Verify bytes match

2. **Test `put` creates directories**
   - Verify the path `{root}/{field_id}/` was created

3. **Test `delete` removes file**
   - Put an image, delete it, then try to read it
   - Verify `read` raises `APIError(404)`

4. **Test `delete_field` removes all files for a field**
   - Put 3 images for same field
   - Call `delete_field`
   - Verify root directory no longer exists

5. **Test `_path` traversal protection**
   - Try to read a key like `../../etc/passwd`
   - Verify raises `APIError(404)`

6. **Test `read` with nonexistent key**
   - Try to read a random key
   - Verify raises `APIError(404)`

**Verification:**
```bash
cd AgriVision-Backend
pytest tests/test_media_storage.py -x -v
# All 6 tests pass in < 500ms. No Docker.
```

**Do NOT:** Modify any existing files.

---

## Task 20: Add Unit Tests for Field Creation Endpoint

**Files to create:** `AgriVision-Backend/tests/test_field_creation.py`

**What to do:**
The field creation endpoint (`POST /api/fields`) is tested in integration tests but has **error paths** that are only partially covered. Write unit tests for the error cases:

1. **Test creation with self-intersecting boundary**
   - Submit coordinates that form a bow-tie shape
   - Verify `APIError(422, "invalid_boundary")`

2. **Test creation with field area < 1 hectare**
   - Submit coordinates forming a tiny polygon
   - Verify `APIError(422, "field_area_out_of_range")`

3. **Test creation when at active field limit**
   - Mock count query to return 5
   - Verify `APIError(409, "active_field_limit")`

4. **Test creation with invalid WKT polygon**
   - Mock `ST_IsValid` to return false
   - Verify `APIError(422, "invalid_boundary")`

**Verification:**
```bash
cd AgriVision-Backend
pytest tests/test_field_creation.py -x -v
# All 4 tests pass
```

**Do NOT:** Modify any existing files.
