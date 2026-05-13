# Graph Report - AgriVision  (2026-05-04)

## Corpus Check
- 71 files · ~80,803 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 459 nodes · 598 edges · 28 communities detected
- Extraction: 92% EXTRACTED · 8% INFERRED · 0% AMBIGUOUS · INFERRED: 50 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `b52ffbce`
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

## God Nodes (most connected - your core abstractions)
1. `View` - 47 edges
2. `FieldSelectionViewModel` - 26 edges
3. `NetworkAgriDataRepository` - 15 edges
4. `CodingKeys` - 15 edges
5. `FirebaseAuthService` - 14 edges
6. `AgriVisionError` - 14 edges
7. `ObservableObject` - 12 edges
8. `MockAuthService` - 12 edges
9. `CodingKeys` - 12 edges
10. `AppCoordinator` - 11 edges

## Surprising Connections (you probably didn't know these)
- `ToastView` --inherits--> `View`  [EXTRACTED]
  Core/UI/ToastView.swift → Features/SensorIntegration/Views/SensorIntegrationView.swift
- `ErrorView` --inherits--> `View`  [EXTRACTED]
  Core/UI/ErrorView.swift → Features/SensorIntegration/Views/SensorIntegrationView.swift
- `ValidationError` --inherits--> `LocalizedError`  [EXTRACTED]
  Core/Utils/ValidationService.swift → Data/Protocols/AuthService.swift
- `AppDelegate` --inherits--> `UIResponder`  [EXTRACTED]
  AppDelegate.swift → SceneDelegate.swift
- `VisualEffectBlur` --inherits--> `UIViewRepresentable`  [EXTRACTED]
  Core/UI/VisualEffectBlur.swift → Features/FieldSelection/Views/FieldSelectionView.swift

## Communities (28 total, 7 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.05
Nodes (38): AIAdvisorCard, RecommendationRow, ShimmerRow, AuthPrimaryButton, AuthTabToggle, AuthTextField, ValidatedAuthTextField, OrDividerView (+30 more)

### Community 1 - "Community 1"
Cohesion: 0.05
Nodes (40): CodingKey, CodingKeys, createdAt, id, role, CodingKeys, areaHa, createdAt (+32 more)

### Community 2 - "Community 2"
Cohesion: 0.06
Nodes (14): AgriDataService, Codable, Identifiable, ChatMessage, ChatMessageRequest, Field, PointCoordinates, SensorConfig (+6 more)

### Community 3 - "Community 3"
Cohesion: 0.06
Nodes (13): AuthCoordinator, ObservableObject, AuthViewModel, LoginViewModel, Field, confirmPassword, email, firstName (+5 more)

### Community 4 - "Community 4"
Cohesion: 0.06
Nodes (13): AppDelegate, SceneDelegate, OnboardingStateService, PreferencesService, FirebaseUserProfileService, MockPreferencesService, MockUserProfileService, UserDefaultsOnboardingStateService (+5 more)

### Community 5 - "Community 5"
Cohesion: 0.09
Nodes (3): AuthService, FirebaseAuthService, MockAuthService

### Community 6 - "Community 6"
Cohesion: 0.09
Nodes (22): LocalizedError, AgriVisionError, emailAlreadyInUse, invalidCredentials, invalidEmail, invalidInternalState, networkUnavailable, operationFailed (+14 more)

### Community 7 - "Community 7"
Cohesion: 0.11
Nodes (3): CLLocationManagerDelegate, MKLocalSearchCompleterDelegate, FieldSelectionViewModel

### Community 8 - "Community 8"
Cohesion: 0.12
Nodes (5): FieldSelectionCoordinator, FieldSelectionData, AddFieldIntroViewModel, FieldDetailsViewModel, AddFieldIntroView

### Community 9 - "Community 9"
Cohesion: 0.11
Nodes (10): MKMapViewDelegate, MKPointAnnotation, NSObject, VisualEffectBlur, UIViewRepresentable, Coordinator, FieldSelectionView, IndexedPointAnnotation (+2 more)

### Community 10 - "Community 10"
Cohesion: 0.14
Nodes (3): DashboardCoordinator, DashboardViewModel, AIChatView

### Community 11 - "Community 11"
Cohesion: 0.23
Nodes (4): Coordinator, AppCoordinator, OnboardingCoordinator, SplashView

### Community 12 - "Community 12"
Cohesion: 0.28
Nodes (3): Encodable, FieldCreateRequest, NetworkAgriDataRepository

### Community 13 - "Community 13"
Cohesion: 0.18
Nodes (3): SettingsCoordinator, SettingsViewModel, SettingsView

### Community 14 - "Community 14"
Cohesion: 0.18
Nodes (5): PreferenceKey, OnboardingViewModel, OnboardingPageView, OnboardingView, ScrollOffsetPreferenceKey

### Community 15 - "Community 15"
Cohesion: 0.29
Nodes (4): ViewModifier, AuthContainerView, GlassmorphismModifier, View

### Community 16 - "Community 16"
Cohesion: 0.29
Nodes (4): View, AppColors, Color, LinearGradient

### Community 18 - "Community 18"
Cohesion: 0.33
Nodes (5): Auth, Dashboard, Onboarding, Splash, UIConstants

### Community 19 - "Community 19"
Cohesion: 0.4
Nodes (3): Shape, BackgroundWaveShape, WeatherCardShape

### Community 20 - "Community 20"
Cohesion: 0.4
Nodes (4): ToastType, error, success, ToastView

### Community 21 - "Community 21"
Cohesion: 0.4
Nodes (3): AnyObject, Coordinator, OnboardingStateService

## Knowledge Gaps
- **78 isolated node(s):** `UIApplicationDelegate`, `UIWindowSceneDelegate`, `success`, `error`, `UIConstants` (+73 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `View` connect `Community 0` to `Community 3`, `Community 8`, `Community 9`, `Community 10`, `Community 11`, `Community 13`, `Community 14`, `Community 15`, `Community 20`?**
  _High betweenness centrality (0.292) - this node is a cross-community bridge._
- **Why does `AppCoordinator` connect `Community 11` to `Community 4`?**
  _High betweenness centrality (0.202) - this node is a cross-community bridge._
- **Why does `ObservableObject` connect `Community 3` to `Community 2`, `Community 7`, `Community 8`, `Community 10`, `Community 13`, `Community 14`?**
  _High betweenness centrality (0.148) - this node is a cross-community bridge._
- **What connects `UIApplicationDelegate`, `UIWindowSceneDelegate`, `success` to the rest of the system?**
  _78 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._