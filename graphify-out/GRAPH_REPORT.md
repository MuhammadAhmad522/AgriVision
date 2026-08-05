# Graph Report - .  (2026-07-26)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1626 nodes · 3008 edges · 96 communities detected
- Extraction: 75% EXTRACTED · 25% INFERRED · 0% AMBIGUOUS · INFERRED: 762 edges (avg confidence: 0.79)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `c3355b5f`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 46|Community 46]]
- [[_COMMUNITY_Community 47|Community 47]]
- [[_COMMUNITY_Community 48|Community 48]]
- [[_COMMUNITY_Community 49|Community 49]]
- [[_COMMUNITY_Community 50|Community 50]]
- [[_COMMUNITY_Community 52|Community 52]]
- [[_COMMUNITY_Community 53|Community 53]]
- [[_COMMUNITY_Community 54|Community 54]]
- [[_COMMUNITY_Community 55|Community 55]]
- [[_COMMUNITY_Community 56|Community 56]]
- [[_COMMUNITY_Community 57|Community 57]]
- [[_COMMUNITY_Community 58|Community 58]]
- [[_COMMUNITY_Community 59|Community 59]]
- [[_COMMUNITY_Community 60|Community 60]]
- [[_COMMUNITY_Community 61|Community 61]]
- [[_COMMUNITY_Community 62|Community 62]]
- [[_COMMUNITY_Community 63|Community 63]]
- [[_COMMUNITY_Community 64|Community 64]]
- [[_COMMUNITY_Community 65|Community 65]]
- [[_COMMUNITY_Community 66|Community 66]]
- [[_COMMUNITY_Community 67|Community 67]]
- [[_COMMUNITY_Community 68|Community 68]]
- [[_COMMUNITY_Community 69|Community 69]]
- [[_COMMUNITY_Community 70|Community 70]]
- [[_COMMUNITY_Community 71|Community 71]]
- [[_COMMUNITY_Community 73|Community 73]]
- [[_COMMUNITY_Community 74|Community 74]]
- [[_COMMUNITY_Community 75|Community 75]]
- [[_COMMUNITY_Community 76|Community 76]]
- [[_COMMUNITY_Community 77|Community 77]]
- [[_COMMUNITY_Community 78|Community 78]]
- [[_COMMUNITY_Community 79|Community 79]]
- [[_COMMUNITY_Community 80|Community 80]]
- [[_COMMUNITY_Community 81|Community 81]]
- [[_COMMUNITY_Community 82|Community 82]]
- [[_COMMUNITY_Community 84|Community 84]]
- [[_COMMUNITY_Community 85|Community 85]]
- [[_COMMUNITY_Community 86|Community 86]]
- [[_COMMUNITY_Community 87|Community 87]]
- [[_COMMUNITY_Community 88|Community 88]]
- [[_COMMUNITY_Community 89|Community 89]]
- [[_COMMUNITY_Community 90|Community 90]]
- [[_COMMUNITY_Community 91|Community 91]]
- [[_COMMUNITY_Community 92|Community 92]]
- [[_COMMUNITY_Community 93|Community 93]]
- [[_COMMUNITY_Community 96|Community 96]]
- [[_COMMUNITY_Community 99|Community 99]]
- [[_COMMUNITY_Community 100|Community 100]]
- [[_COMMUNITY_Community 101|Community 101]]
- [[_COMMUNITY_Community 102|Community 102]]
- [[_COMMUNITY_Community 103|Community 103]]

## God Nodes (most connected - your core abstractions)
1. `MockAuthService` - 121 edges
2. `MockAgriDataRepository` - 116 edges
3. `date` - 52 edges
4. `APIError` - 51 edges
5. `MockPreferencesService` - 46 edges
6. `FieldSelectionViewModel` - 45 edges
7. `FieldSessionStore` - 45 edges
8. `SettingsViewModel` - 35 edges
9. `DashboardViewModel` - 32 edges
10. `NetworkAgriDataRepository` - 28 edges

## Surprising Connections (you probably didn't know these)
- `NetworkAgriDataRepository` --communicates_with--> `FastAPI Backend`  [EXTRACTED]
  Docs/api-services-summary.md → AgriVision-Backend/requirements.txt
- `FastAPI Backend` --consumes--> `Gemini AI (Vertex AI)`  [EXTRACTED]
  AgriVision-Backend/requirements.txt → Docs/api-services-summary.md
- `Fields API Router` --part_of--> `FastAPI Backend`  [EXTRACTED]
  Docs/api-services-summary.md → AgriVision-Backend/requirements.txt
- `Sensors API Router` --part_of--> `FastAPI Backend`  [EXTRACTED]
  Docs/api-services-summary.md → AgriVision-Backend/requirements.txt
- `Recommendations API Router` --part_of--> `FastAPI Backend`  [EXTRACTED]
  Docs/api-services-summary.md → AgriVision-Backend/requirements.txt

## Communities (111 total, 31 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.06
Nodes (81): lifespan(), max, min, cache_scene_image(), _cache_set(), create_polygon(), delete_polygon(), get_accumulated_precipitation() (+73 more)

### Community 1 - "Community 1"
Cohesion: 0.05
Nodes (17): Coordinator, AppCoordinator, AuthCoordinator, DashboardCoordinator, FieldSelectionCoordinator, OnboardingCoordinator, SettingsCoordinator, BackendConnectionView (+9 more)

### Community 2 - "Community 2"
Cohesion: 0.05
Nodes (45): AI Agent Task Queue (20 tasks), AgriVision, ValidationErrorTests, ValidationServiceTests, AgroMonitoring API, AgroMonitoring REST Client Service, AI Advisor Service, AI Safety Policy & Guardrails (+37 more)

### Community 3 - "Community 3"
Cohesion: 0.08
Nodes (7): ForgotPasswordViewModelTests, LoginViewModelTests, SettingsViewModelTests, MockAuthService, MockPreferencesService, LoginViewModel, SettingsViewModel

### Community 4 - "Community 4"
Cohesion: 0.06
Nodes (5): FieldSelectionViewModelTests, CLLocationManagerDelegate, MKLocalSearchCompleterDelegate, MockAgriDataRepository, FieldSelectionViewModel

### Community 5 - "Community 5"
Cohesion: 0.07
Nodes (47): bootstrap(), BaseModel, ChatAttachmentResponse, ChatMessageRequest, ChatMessageResponse, ChatTurnResponse, ErrorBody, ErrorEnvelope (+39 more)

### Community 6 - "Community 6"
Cohesion: 0.09
Nodes (43): Base, Exception, AgronomyKnowledgeDocument, AIAnalysisRun, AIChatMessage, AIChatThread, ChatAttachment, Field (+35 more)

### Community 7 - "Community 7"
Cohesion: 0.07
Nodes (34): get_current_user(), _apply_safety_policy(), _approved_url(), _canonical_category(), chat_with_advisor(), CuratedKnowledgeProvider, GeminiAIProvider, generate_field_recommendations() (+26 more)

### Community 8 - "Community 8"
Cohesion: 0.05
Nodes (6): APIClientTests, MockTokenAuthService, MockURLProtocol, AuthService, FirebaseAuthService, URLProtocol

### Community 9 - "Community 9"
Cohesion: 0.07
Nodes (18): Codable, Identifiable, ChatAttachment, ChatImageUpload, ChatMessage, ChatTurn, Field, PointCoordinates (+10 more)

### Community 10 - "Community 10"
Cohesion: 0.09
Nodes (3): DashboardViewModelTests, FieldSessionStore, DashboardViewModel

### Community 11 - "Community 11"
Cohesion: 0.09
Nodes (11): AuthViewModelTests, SignupViewModelTests, MockUserProfileService, AuthViewModel, Field, confirmPassword, email, firstName (+3 more)

### Community 12 - "Community 12"
Cohesion: 0.09
Nodes (6): FieldSessionStoreTests, FieldRecommendationTests, FieldReplacingCoordinatesTests, SensorReadingTests, date, XCTestCase

### Community 13 - "Community 13"
Cohesion: 0.06
Nodes (17): MKMapViewDelegate, MKPointAnnotation, NSObject, VisualEffectBlur, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIViewControllerRepresentable, UIViewRepresentable (+9 more)

### Community 15 - "Community 15"
Cohesion: 0.07
Nodes (11): AppDelegate, SceneDelegate, OnboardingStateService, PreferencesService, FirebaseUserProfileService, UserDefaultsOnboardingStateService, UserDefaultsPreferencesService, UIApplicationDelegate (+3 more)

### Community 16 - "Community 16"
Cohesion: 0.08
Nodes (23): LocalizedError, AgriVisionError, emailAlreadyInUse, invalidCredentials, invalidEmail, invalidInternalState, networkUnavailable, operationFailed (+15 more)

### Community 17 - "Community 17"
Cohesion: 0.14
Nodes (20): View, AlertRow, AlertsBottomSheet, DashboardHeaderView, DashboardLayout, DashboardView, ForecastCardView, HealthCardView (+12 more)

### Community 18 - "Community 18"
Cohesion: 0.13
Nodes (14): get_field_readings(), pair_sensor(), Claim an online, unowned device for the authenticated tenant.      A device is p, verify_sensor_connection(), api_error_handler(), http_error_handler(), _initialize_firebase(), request_context() (+6 more)

### Community 19 - "Community 19"
Cohesion: 0.11
Nodes (3): AgriDataService, FieldCreateRequest, NetworkAgriDataRepository

### Community 20 - "Community 20"
Cohesion: 0.13
Nodes (6): OnboardingViewModelTests, PreferenceKey, OnboardingViewModel, OnboardingPageView, OnboardingView, ScrollOffsetPreferenceKey

### Community 21 - "Community 21"
Cohesion: 0.1
Nodes (21): CodingKeys, agroError, agromonitoringPolygonId, agroRetryable, agroStatus, archivedAt, areaHa, coordinates (+13 more)

### Community 22 - "Community 22"
Cohesion: 0.15
Nodes (13): Decodable, AdvisorSnapshot, DashboardSnapshot, DashboardSources, DataAvailabilityItem, SatelliteSnapshot, SourceState, UVISnapshot (+5 more)

### Community 23 - "Community 23"
Cohesion: 0.14
Nodes (5): MockMessage, MockSensor, TestAcceptDeviceMessage, TestOnMessage, TestWriteBatch

### Community 24 - "Community 24"
Cohesion: 0.15
Nodes (8): ABC, AIProvider, GCSPrivateMediaStorage, PrivateMediaStorage, sanitize_upload(), _jpeg_with_metadata(), test_declared_type_spoofing_is_rejected(), test_image_is_resized_reencoded_and_metadata_removed()

### Community 25 - "Community 25"
Cohesion: 0.19
Nodes (18): _assign_paired_sensor(), assign_sensor(), _coordinates_to_wkt(), create_field(), delete_field(), field_to_response(), get_dashboard(), get_field() (+10 more)

### Community 26 - "Community 26"
Cohesion: 0.11
Nodes (19): CodingKeys, acquiredAt, cloudPercent, configuredCount, coveragePercent, data, dataQuality, lastUpdated (+11 more)

### Community 27 - "Community 27"
Cohesion: 0.18
Nodes (3): FieldDetailsViewModelTests, ObservableObject, FieldDetailsViewModel

### Community 28 - "Community 28"
Cohesion: 0.11
Nodes (15): CodingKeys, assistantMessage, attachments, byteSize, content, createdAt, height, id (+7 more)

### Community 29 - "Community 29"
Cohesion: 0.11
Nodes (18): CodingKeys, advice, category, confidence, confidenceReason, createdAt, evidence, expiresAt (+10 more)

### Community 30 - "Community 30"
Cohesion: 0.22
Nodes (14): _csv_stream(), export_chat(), export_observations(), export_recommendations(), export_satellite_scenes(), export_sensor_readings(), owned_field(), _apply_feedback() (+6 more)

### Community 31 - "Community 31"
Cohesion: 0.25
Nodes (3): SensorIntegrationViewModelTests, FieldSelectionData, SensorIntegrationViewModel

### Community 32 - "Community 32"
Cohesion: 0.12
Nodes (5): BackendAPIErrorTests, DataSourceStatusTests, FieldDecodingTests, PointCoordinatesTests, SensorConfigTests

### Community 33 - "Community 33"
Cohesion: 0.24
Nodes (3): LocalPrivateMediaStorage, SanitizedImage, TestLocalPrivateMediaStorage

### Community 34 - "Community 34"
Cohesion: 0.38
Nodes (13): _make_sensor_row(), _mock_db(), _mock_user(), _parse_csv(), test_export_chat(), test_export_empty_results(), test_export_observations(), test_export_recommendations() (+5 more)

### Community 35 - "Community 35"
Cohesion: 0.12
Nodes (16): CodingKeys, current, depthTempC, description, fieldId, forecastDays, humidity, moisture (+8 more)

### Community 36 - "Community 36"
Cohesion: 0.15
Nodes (11): AlertRow, AlertsBottomSheet, CustomTabBar, MoistureCardView, NDVICardView, PHBubbleShape, PHLevelCardView, TabBarButton (+3 more)

### Community 38 - "Community 38"
Cohesion: 0.21
Nodes (3): AnyEncodable, APIClient, Data

### Community 39 - "Community 39"
Cohesion: 0.19
Nodes (11): _accept_device_message(), _db_writer_loop(), on_message(), Write a batch of sensor readings to DB in a single transaction., Consume from the async queue and batch-write readings to the database., Start the MQTT client in a background thread (blocking)., Initialise the async queue and launch the MQTT bridge + DB writer., Fast path: validate and enqueue reading. DB writes happen in the     background (+3 more)

### Community 40 - "Community 40"
Cohesion: 0.35
Nodes (10): _mock_db(), _mock_user(), test_get_sensor_readings_returns_readings(), test_get_sensor_readings_with_no_sensors_returns_empty(), test_pair_sensor_owned_by_another_tenant_returns_409(), test_pair_sensor_with_offline_sensor_returns_409(), test_pair_sensor_with_online_unowned_sensor(), test_verify_sensor_with_invalid_device_id_returns_422() (+2 more)

### Community 41 - "Community 41"
Cohesion: 0.33
Nodes (5): _make_scene(), _mock_db(), _mock_user(), TestImage, TestLatest

### Community 42 - "Community 42"
Cohesion: 0.23
Nodes (4): _configure_db_query(), _make_message(), test_get_history_returns_paginated_messages(), test_get_history_with_before_parameter()

### Community 43 - "Community 43"
Cohesion: 0.29
Nodes (11): _existing_turn(), get_attachment(), get_history(), _lock_turn(), _message_response(), post_message(), Serialize duplicate submissions across workers without persisting a draft row., _thread_for_field() (+3 more)

### Community 45 - "Community 45"
Cohesion: 0.41
Nodes (9): _make_recommendation(), _mock_db(), _mock_user(), test_feedback_with_nonexistent_recommendation(), test_feedback_with_valid_status(), test_get_recommendations_returns_list(), test_outcome_with_pending_recommendation(), test_outcome_with_valid_implemented_recommendation() (+1 more)

### Community 46 - "Community 46"
Cohesion: 0.26
Nodes (9): FirebaseAuthErrorMapper, _connect_mqtt(), _connect_wifi(), _init_device_id(), loop(), _publish_sensors(), _read_moisture(), _read_temperature() (+1 more)

### Community 47 - "Community 47"
Cohesion: 0.17
Nodes (12): CodingKeys, areaHa, coordinates, cropType, deviceId, expectedHarvestDate, isPaired, isVerified (+4 more)

### Community 48 - "Community 48"
Cohesion: 0.17
Nodes (12): CodingKeys, batteryLevel, deviceId, fieldId, id, lastSeen, name, sensorType (+4 more)

### Community 49 - "Community 49"
Cohesion: 0.18
Nodes (7): AIAdvisorCard, RecommendationRow, ShimmerRow, View, AppColors, Color, LinearGradient

### Community 50 - "Community 50"
Cohesion: 0.25
Nodes (7): InMemoryRateLimiter, Small local limiter. Replace with Redis when running multiple API replicas., test_accepts_request_under_limit(), test_different_keys_dont_interfere(), test_rejects_request_over_limit(), test_retryable_flag_is_set(), test_window_expiry_resets_counter()

### Community 52 - "Community 52"
Cohesion: 0.33
Nodes (8): _add_column(), _create_index(), _ensure_cascade_fk(), _has_column(), _has_table(), _has_unique(), status, hard deletion, multimodal chat, and AI evidence  Revision ID: 0002_multi, upgrade()

### Community 53 - "Community 53"
Cohesion: 0.22
Nodes (9): Add Field Image, Add Field Image Blurred, App Logo, Background Image, Onboarding Image 3, Onboarding Leaf, Onboarding Leaf 2, Onboarding Leaf 2 Blurred (+1 more)

### Community 54 - "Community 54"
Cohesion: 0.22
Nodes (5): EditProfileSheet, SensorPairingSheet, SettingsInfoRow, SettingsView, StatusPill

### Community 55 - "Community 55"
Cohesion: 0.44
Nodes (6): _mock_db(), _mock_user(), test_creation_when_at_active_field_limit(), test_creation_with_field_area_less_than_one_hectare(), test_creation_with_invalid_wkt_polygon(), test_creation_with_self_intersecting_boundary()

### Community 56 - "Community 56"
Cohesion: 0.25
Nodes (7): CropSelectionSheet, DateSelectionSheet, FieldDetailsView, FieldSelectionBox, FieldSubmitButton, FieldTextFieldBox, FieldToggleBox

### Community 57 - "Community 57"
Cohesion: 0.25
Nodes (8): CodingKeys, activeFieldCount, activeFieldLimit, email, fields, firebaseUid, id, user

### Community 58 - "Community 58"
Cohesion: 0.43
Nodes (5): _add(), _columns(), _create_index(), multi-tenant multi-field foundation  Revision ID: 0001_multitenant Revises:, upgrade()

### Community 59 - "Community 59"
Cohesion: 0.29
Nodes (7): CodingKey, CodingKeys, code, details, message, requestId, retryable

### Community 60 - "Community 60"
Cohesion: 0.29
Nodes (4): Encodable, FeedbackRequest, OutcomeRequest, PairSensorRequest

### Community 62 - "Community 62"
Cohesion: 0.29
Nodes (5): APIDateCoding, ErrorBody, ErrorEnvelope, FieldError, MultipartFile

### Community 63 - "Community 63"
Cohesion: 0.29
Nodes (7): DataSourceStatus, available, notConfigured, pending, stale, unavailable, unsupported

### Community 64 - "Community 64"
Cohesion: 0.4
Nodes (3): BackgroundWave, BackgroundWaveShape, WaveBackground

### Community 66 - "Community 66"
Cohesion: 0.6
Nodes (5): _image(), latest(), _latest_scene(), ndvi_image(), truecolor_image()

### Community 67 - "Community 67"
Cohesion: 0.33
Nodes (5): Auth, Dashboard, Onboarding, Splash, UIConstants

### Community 68 - "Community 68"
Cohesion: 0.4
Nodes (5): Hashable, DashboardTab, fields, home, settings

### Community 69 - "Community 69"
Cohesion: 0.4
Nodes (4): ToastType, error, success, ToastView

### Community 71 - "Community 71"
Cohesion: 0.4
Nodes (3): AnyObject, Coordinator, OnboardingStateService

## Knowledge Gaps
- **196 isolated node(s):** `Redis Cache`, `Recommendations API Router`, `Satellite Imagery API Router`, `Session Bootstrap API Router`, `MVVM-C Architecture Pattern` (+191 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **31 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `min` connect `Community 0` to `Community 26`, `Community 4`, `Community 46`, `Community 7`?**
  _High betweenness centrality (0.317) - this node is a cross-community bridge._
- **Why does `APIError` connect `Community 18` to `Community 0`, `Community 33`, `Community 66`, `Community 6`, `Community 7`, `Community 41`, `Community 43`, `Community 50`, `Community 24`, `Community 25`, `Community 30`?**
  _High betweenness centrality (0.185) - this node is a cross-community bridge._
- **Why does `MockAuthService` connect `Community 3` to `Community 4`, `Community 8`, `Community 10`, `Community 11`, `Community 12`, `Community 27`, `Community 31`?**
  _High betweenness centrality (0.122) - this node is a cross-community bridge._
- **Are the 108 inferred relationships involving `MockAuthService` (e.g. with `.test_initialState()` and `.test_profileInitial_fromDisplayName()`) actually correct?**
  _`MockAuthService` has 108 INFERRED edges - model-reasoned connections that need verification._
- **Are the 93 inferred relationships involving `MockAgriDataRepository` (e.g. with `.test_initialState()` and `.test_profileInitial_fromDisplayName()`) actually correct?**
  _`MockAgriDataRepository` has 93 INFERRED edges - model-reasoned connections that need verification._
- **Are the 51 inferred relationships involving `date` (e.g. with `.test_healthSummary_excellent()` and `.test_healthSummary_monitor()`) actually correct?**
  _`date` has 51 INFERRED edges - model-reasoned connections that need verification._
- **Are the 48 inferred relationships involving `APIError` (e.g. with `InMemoryRateLimiter` and `SanitizedImage`) actually correct?**
  _`APIError` has 48 INFERRED edges - model-reasoned connections that need verification._