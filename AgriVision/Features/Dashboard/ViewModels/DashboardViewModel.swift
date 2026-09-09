import Combine
import Foundation
import UIKit

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var recommendations: [FieldRecommendation] = []
    @Published var seasonMemory: SeasonMemory?
    @Published var advisorStatus = "pending"
    @Published var advisorMessage: String?
    @Published var advisorDataQuality: String?
    @Published var advisorRunId: UUID?
    @Published var advisorRunStatus: String?
    @Published var loadedFieldId: UUID?
    @Published var readings: [SensorReading] = []
    @Published var sensorFleet: [SensorFleetEntry] = []
    @Published var weatherSoil: FieldWeatherSoil?
    @Published var satellite: SourceState<SatelliteSnapshot>?
    @Published var satelliteImageData: Data?
    @Published var truecolorImageData: Data?
    @Published var uvi: SourceState<UVISnapshot>?
    @Published var sensorCount = 0
    @Published var sensorStatus = "not_configured"
    @Published var dataAvailability: [DataAvailabilityItem] = []
    @Published var isLoading = false
    @Published var isRefreshingAI = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var userName: String?
    @Published var profileImageURL: URL?
    @Published var profileInitial = "U"
    @Published var lastUpdatedAt: Date?
    @Published var notifications: [UserNotification] = []
    @Published var unreadNotificationsCount = 0

    let fieldSessionStore: FieldSessionStore
    let dataService: AgriDataService
    private let authService: AuthService
    private let preferencesService: PreferencesService
    private var cancellables: Set<AnyCancellable> = []
    private var dashboardRequestToken: UUID?
    // Notification ids seen on the previous inbox poll. A newly-arrived expert review or
    // agronomist-guidance change means this field's recommendations changed server-side;
    // without noticing that here, the recommendation card stays locked / shows a stale
    // verdict until the 5-minute full-dashboard tier catches up.
    private var lastKnownNotificationIDs: Set<UUID> = []
    private var hasPolledNotificationsOnce = false

    // The app is hosted by UIKit (AppDelegate/SceneDelegate + UIHostingController), so
    // SwiftUI's @Environment(\.scenePhase) is never populated and cannot gate polling.
    // Track foreground state from UIApplication notifications instead.
    private var isAppActive = true

    // Matches the backend's own external-data scan cadence (AGRO_WORKER_SCAN_SECONDS in
    // AgriVision-Backend). Polling faster than the backend itself checks for new satellite/
    // weather/soil data or reconsiders AI recommendations cannot surface anything newer —
    // it would just re-download unchanged satellite images and recommendation text.
    private static let fullDashboardRefreshInterval: TimeInterval = 300

    // Notifications are cheap (one small list query) and time-sensitive, so they poll
    // continuously in the background to provide near-instantaneous updates.
    private static let notificationPollInterval: TimeInterval = 5

    // How often, and for how long, a user-triggered "Refresh advice" waits on the analysis
    // run it started. The AI call itself is the slow part; the bound exists so the button
    // always stops spinning even when the backend never picks the job up.
    private static let advisorPollInterval: TimeInterval = 2
    private static let advisorPollTimeout: TimeInterval = 90

    var onSignOut: (() -> Void)?
    var onSettingsTap: (() -> Void)?
    var onChatTapped: ((UUID) -> Void)?
    var onAddFieldTapped: (() -> Void)?
    var onFieldsEmptied: (() -> Void)?

    init(dataService: AgriDataService, authService: AuthService, preferencesService: PreferencesService, fieldSessionStore: FieldSessionStore) {
        self.dataService = dataService
        self.authService = authService
        self.preferencesService = preferencesService
        self.fieldSessionStore = fieldSessionStore
        userName = authService.currentUserDisplayName
        profileImageURL = authService.currentUserPhotoURL
        if let name = authService.currentUserDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines), let character = name.split(separator: " ").last?.first {
            profileInitial = String(character).uppercased()
        }
        fieldSessionStore.$activeFieldId
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                self?.clearFieldData()
                Task { await self?.refreshData() }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isAppActive = true
                    await self.catchUpAfterForeground()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { _ in
                Task { @MainActor [weak self] in self?.isAppActive = false }
            }
            .store(in: &cancellables)
    }

    var activeField: Field? { fieldSessionStore.activeField }
    var fields: [Field] { fieldSessionStore.fields }
    var currentCropType: String { activeField?.cropType ?? "Unknown crop" }

    var healthSummary: (score: Double?, label: String, rationale: String?, updatedAt: Date?)? {
        guard let field = activeField else { return nil }
        return (field.latestHealthScore, field.latestHealthLabel ?? "insufficient_data", field.latestHealthRationale, field.latestHealthUpdatedAt)
    }

    var showHarvestAlert: Bool {
        return recommendations.contains { $0.category == "Harvest Timing" && $0.priority == "high" }
    }

    func signOut() {
        do { try authService.signOut(); fieldSessionStore.clear(); onSignOut?() }
        catch { errorMessage = error.userFacingMessage }
    }

    func openSettings() { onSettingsTap?() }
    func openChat() { if let id = fieldSessionStore.activeFieldId { onChatTapped?(id) } }
    func addField() {
        if fieldSessionStore.hasReachedLimit {
            presentError("Delete a field before adding another. You can have up to \(fieldSessionStore.activeFieldLimit) fields.")
        } else {
            onAddFieldTapped?()
        }
    }

    func harvestNow() {
        guard fieldSessionStore.activeFieldId != nil else { return }
        isLoading = true
        Task {
            do {
                try await fieldSessionStore.deleteActiveField()
                isLoading = false
                if fieldSessionStore.fields.isEmpty {
                    onFieldsEmptied?()
                }
            } catch {
                isLoading = false
                presentError(error.userFacingMessage)
            }
        }
    }

    func pollUntilCancelled() async {
        // Seed once so the fast tier knows whether any sensors are configured before its
        // first tick — otherwise sensorCount is still 0 and that tick is wasted.
        await refreshData()
        async let sensors: Void = pollSensorReadings()
        async let dashboard: Void = pollFullDashboard()
        async let notifications: Void = pollNotifications()
        _ = await (sensors, dashboard, notifications)
    }

    private func pollSensorReadings() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(preferencesService.dashboardRefreshInterval))
            guard !Task.isCancelled, isAppActive else { continue }
            await refreshSensorReadingsOnly()
        }
    }

    private func pollFullDashboard() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Self.fullDashboardRefreshInterval))
            guard !Task.isCancelled, isAppActive else { continue }
            await refreshData()
        }
    }

    /// Returning from the background can leave readings arbitrarily stale, so catch up
    /// immediately rather than waiting out the remainder of the poll interval.
    private func catchUpAfterForeground() async {
        guard fieldSessionStore.activeFieldId != nil else { return }
        let age = lastUpdatedAt.map { Date().timeIntervalSince($0) } ?? .greatestFiniteMagnitude
        if age >= Self.fullDashboardRefreshInterval {
            await refreshData()
        } else {
            await refreshSensorReadingsOnly()
        }
    }

    private func refreshSensorReadingsOnly() async {
        guard let fieldID = fieldSessionStore.activeFieldId, sensorCount > 0 else { return }
        guard let newReadings = try? await dataService.fetchSensorReadings(for: fieldID) else { return }
        guard fieldID == fieldSessionStore.activeFieldId else { return }
        readings = newReadings
        // Fast tier: keep each sensor's values fresh without re-checking online/offline
        // status, which only needs the slower full-dashboard tier's cadence.
        let latestBySensor = Dictionary(newReadings.map { ($0.sensor_id, $0) }, uniquingKeysWith: { a, b in a.time > b.time ? a : b })
        for index in sensorFleet.indices {
            if let fresh = latestBySensor[sensorFleet[index].sensorId] {
                sensorFleet[index].reading = fresh
            }
        }
        lastUpdatedAt = Date()
    }

    func refreshData() async {
        guard let fieldID = fieldSessionStore.activeFieldId else {
            clearFieldData()
            return
        }
        let requestToken = UUID()
        dashboardRequestToken = requestToken
        isLoading = true
        defer {
            if dashboardRequestToken == requestToken {
                isLoading = false
            }
        }
        do {
            let snapshot = try await dataService.fetchDashboard(for: fieldID)
            guard fieldID == fieldSessionStore.activeFieldId, dashboardRequestToken == requestToken else { return }
            guard snapshot.field.id == fieldID else {
                presentError("Dashboard data did not match the selected field. Please refresh and try again.")
                return
            }
            fieldSessionStore.merge(snapshot.field)
            loadedFieldId = fieldID
            recommendations = snapshot.recommendations.filter { $0.fieldId == fieldID }
            advisorStatus = snapshot.advisor?.status ?? (recommendations.isEmpty ? "pending" : "available")
            advisorMessage = snapshot.advisor?.message
            advisorDataQuality = snapshot.advisor?.dataQuality
            advisorRunId = snapshot.advisor?.runId
            advisorRunStatus = snapshot.advisor?.runStatus
            // The 5s telemetry tier owns `readings` once it has data. The dashboard snapshot
            // carries a different, smaller window (50 rows vs the telemetry endpoint's 240),
            // so overwriting here made the charts visibly shrink every full refresh.
            if readings.isEmpty {
                readings = snapshot.sources.sensors.data ?? []
            }
            sensorFleet = snapshot.sources.sensorFleet
            sensorCount = snapshot.sources.sensors.configuredCount ?? Set(readings.map(\.sensor_id)).count
            sensorStatus = snapshot.sources.sensors.status
            satellite = snapshot.sources.satellite
            uvi = snapshot.sources.uvi
            let soil = snapshot.sources.soil.data ?? FieldWeatherSoil.SoilData(moisture: nil, surfaceTempC: nil, depthTempC: nil, source: snapshot.sources.soil.status)
            let weather = snapshot.sources.weather.data ?? FieldWeatherSoil.WeatherData(current: .init(tempC: nil, humidity: nil, description: nil), forecastDays: [], source: snapshot.sources.weather.status)
            weatherSoil = FieldWeatherSoil(fieldId: fieldID, soil: soil, weather: weather)
            dataAvailability = availabilityItems(from: snapshot.sources)
            errorMessage = nil
            await loadSatelliteImages(
                for: fieldID,
                requestToken: requestToken,
                hasNDVI: snapshot.sources.satellite.data?.ndviImageURL != nil,
                hasTruecolor: snapshot.sources.satellite.data?.truecolorImageURL != nil
            )
            // Best-effort: a missing crop journal (e.g. no plantation date set yet) is a normal
            // state, not a dashboard-load failure.
            seasonMemory = try? await dataService.fetchSeasonMemory(for: fieldID)
            await refreshNotifications()
            lastUpdatedAt = Date()
        } catch is CancellationError {
        } catch {
            guard fieldID == fieldSessionStore.activeFieldId, dashboardRequestToken == requestToken else { return }
            presentError(error.userFacingMessage)
        }
    }

    private func clearFieldData() {
        dashboardRequestToken = nil
        recommendations = []
        seasonMemory = nil
        advisorStatus = "pending"
        advisorMessage = nil
        advisorDataQuality = nil
        advisorRunId = nil
        advisorRunStatus = nil
        loadedFieldId = nil
        readings = []
        sensorFleet = []
        weatherSoil = nil
        satellite = nil
        satelliteImageData = nil
        truecolorImageData = nil
        uvi = nil
        sensorCount = 0
        sensorStatus = "not_configured"
        dataAvailability = []
        errorMessage = nil
        lastUpdatedAt = nil
    }

    private func loadSatelliteImages(for fieldID: UUID, requestToken: UUID, hasNDVI: Bool, hasTruecolor: Bool) async {
        async let ndviData: Data? = hasNDVI ? try? dataService.fetchSatelliteImage(for: fieldID, kind: "ndvi") : nil
        async let truecolorData: Data? = hasTruecolor ? try? dataService.fetchSatelliteImage(for: fieldID, kind: "truecolor") : nil
        let images = await (ndviData, truecolorData)
        guard fieldID == fieldSessionStore.activeFieldId, dashboardRequestToken == requestToken else { return }
        satelliteImageData = images.0
        truecolorImageData = images.1
    }

    /// Applies only the advisor slice of a dashboard snapshot: the recommendations and the
    /// state of the analysis run behind them. The refresh poll ticks every couple of seconds,
    /// and a full `refreshData()` per tick would re-download satellite imagery, re-fetch
    /// notifications, and contend with the background poller for `dashboardRequestToken` —
    /// losing that race means discarding the very response the poll was waiting for.
    /// Force an immediate recommendations-only refresh. Used when the farmer opens an
    /// expert-review notification: the card must reflect the agronomist's verdict (and
    /// unlock) right then, not on the next poll tick.
    func syncRecommendationsNow() async {
        guard let fieldID = fieldSessionStore.activeFieldId else { return }
        await applyAdvisorSlice(for: fieldID)
    }

    @discardableResult
    private func applyAdvisorSlice(for fieldID: UUID) async -> Bool {
        guard let snapshot = try? await dataService.fetchDashboard(for: fieldID) else { return false }
        guard fieldID == fieldSessionStore.activeFieldId, snapshot.field.id == fieldID else { return false }
        recommendations = snapshot.recommendations.filter { $0.fieldId == fieldID }
        advisorStatus = snapshot.advisor?.status ?? (recommendations.isEmpty ? "pending" : "available")
        advisorMessage = snapshot.advisor?.message
        advisorDataQuality = snapshot.advisor?.dataQuality
        advisorRunId = snapshot.advisor?.runId
        advisorRunStatus = snapshot.advisor?.runStatus
        return true
    }

    func refreshRecommendations() async {
        guard let fieldID = fieldSessionStore.activeFieldId, !isRefreshingAI else { return }
        isRefreshingAI = true
        defer { isRefreshingAI = false }

        // The backend runs the re-analysis as a background job and answers the trigger
        // immediately with whatever advice already existed, so a single refetch would show
        // unchanged text under a "updated" toast. Wait on the run itself: a run whose id
        // differs from the one showing at trigger time and that is no longer "running" is
        // this refresh's own result, whether or not it wrote new advice. Comparing
        // recommendation timestamps against the device clock cannot do this — a run can
        // legitimately finish without producing a recommendation, and the backend reports
        // both "still running" and "finished with nothing to say" as advisorStatus "pending".
        // Read the baseline from the server rather than from whatever this session happens to
        // hold: an advisorRunId still nil because no dashboard load has landed yet would make
        // the very first poll mistake the *previous* run for this refresh's own result.
        let hasBaseline = await applyAdvisorSlice(for: fieldID)
        guard fieldID == fieldSessionStore.activeFieldId else { return }
        let previousRunId = advisorRunId
        let knownIDs = Set(recommendations.map(\.id))
        do {
            advisorStatus = "pending"
            advisorMessage = "AI is reviewing the latest field evidence."
            try await dataService.refreshRecommendations(for: fieldID)
            guard fieldID == fieldSessionStore.activeFieldId else { return }

            let deadline = Date().addingTimeInterval(Self.advisorPollTimeout)
            // Without a baseline to compare against, any run id looks new — so wait to watch
            // a run actually start rather than mistaking the previous one for this result.
            var sawRunStart = hasBaseline
            while Date() < deadline {
                try? await Task.sleep(for: .seconds(Self.advisorPollInterval))
                guard fieldID == fieldSessionStore.activeFieldId else { return }
                guard await applyAdvisorSlice(for: fieldID) else { continue }
                guard fieldID == fieldSessionStore.activeFieldId else { return }

                // Still showing the run that was current before the trigger — the job has
                // not been picked up yet.
                guard let runId = advisorRunId, runId != previousRunId else { continue }
                guard advisorRunStatus != "running" else { sawRunStart = true; continue }
                guard sawRunStart else { continue }

                await finishAdvisorRefresh(for: fieldID, knownIDs: knownIDs)
                return
            }
            // The job never surfaced a run of its own — the backend skips a trigger while an
            // analysis is already in flight for this field. Say so instead of spinning on.
            presentError("AI is still analysing this field. The advice will update on its own once it finishes.")
        } catch {
            guard fieldID == fieldSessionStore.activeFieldId else { return }
            advisorStatus = "unavailable"
            advisorMessage = error.userFacingMessage
            presentError(error.userFacingMessage)
        }
    }

    /// Settles the UI once the triggered run has finished: the journal it may have written,
    /// and a toast that distinguishes new advice from a review that found nothing to change.
    private func finishAdvisorRefresh(for fieldID: UUID, knownIDs: Set<UUID>) async {
        let hasNewAdvice = recommendations.contains { !knownIDs.contains($0.id) }
        seasonMemory = try? await dataService.fetchSeasonMemory(for: fieldID)
        guard fieldID == fieldSessionStore.activeFieldId else { return }
        lastUpdatedAt = Date()

        if advisorRunStatus == "failed" {
            presentError(advisorMessage ?? "AI Advisor could not complete the latest analysis.")
            return
        }
        successMessage = hasNewAdvice
            ? "Advice updated with the latest insights."
            : "AI reviewed your field — no new advice needed."
        ToastMessageAutoDismiss.schedule(expectedMessage: successMessage ?? "", currentMessage: { [weak self] in self?.successMessage }, clearMessage: { [weak self] in self?.successMessage = nil })
    }

    func updateFeedback(_ recommendation: FieldRecommendation, status: String) async {
        do {
            let updated = try await dataService.updateRecommendationFeedback(for: recommendation.fieldId, recommendationId: recommendation.id, status: status)
            guard updated.fieldId == fieldSessionStore.activeFieldId else { return }
            if let index = recommendations.firstIndex(where: { $0.id == updated.id }) { recommendations[index] = updated }
        } catch { presentError(error.userFacingMessage) }
    }

    func recordOutcome(_ recommendation: FieldRecommendation, outcome: String) async {
        do {
            let updated = try await dataService.recordRecommendationOutcome(
                for: recommendation.fieldId,
                recommendationId: recommendation.id,
                outcome: outcome,
                notes: nil
            )
            guard updated.fieldId == fieldSessionStore.activeFieldId else { return }
            if let index = recommendations.firstIndex(where: { $0.id == updated.id }) { recommendations[index] = updated }
            successMessage = "Outcome recorded."
            ToastMessageAutoDismiss.schedule(expectedMessage: successMessage ?? "", currentMessage: { [weak self] in self?.successMessage }, clearMessage: { [weak self] in self?.successMessage = nil })
        } catch { presentError(error.userFacingMessage) }
    }

    func requestDataRefresh() async {
        guard let fieldID = fieldSessionStore.activeFieldId else { return }
        do {
            try await dataService.refreshFieldData(for: fieldID)
            successMessage = "Data refresh queued."
            ToastMessageAutoDismiss.schedule(expectedMessage: successMessage ?? "", currentMessage: { [weak self] in self?.successMessage }, clearMessage: { [weak self] in self?.successMessage = nil })
        } catch {
            presentError(error.userFacingMessage)
        }
    }

    /// Notifications used to refresh only as a side effect of a full dashboard load, so
    /// expert advice sent while the farmer sat on the dashboard did not appear until they
    /// switched field or backgrounded the app. This is the public entry point used by both
    /// the dashboard load and the inbox's own poll.
    func refreshNotifications() async {
        guard let fetched = try? await dataService.fetchNotifications() else { return }
        let previousIDs = lastKnownNotificationIDs
        let firstPoll = !hasPolledNotificationsOnce
        hasPolledNotificationsOnce = true
        lastKnownNotificationIDs = Set(fetched.map(\.id))
        notifications = fetched
        unreadNotificationsCount = fetched.filter { !$0.isRead }.count

        // An expert approve/reject (reference_type "recommendation") or a new agronomist
        // guidance directive both change this field's recommendations on the server. Pull
        // the fresh recommendation state now so the card unlocks / updates its verdict
        // within one 60s notification tick instead of waiting out the 300s dashboard tier.
        guard !firstPoll, let fieldID = fieldSessionStore.activeFieldId else { return }
        let touchesRecommendations = fetched.contains { notif in
            !previousIDs.contains(notif.id)
                && (notif.fieldId == fieldID || notif.fieldId == nil)
                && (notif.referenceType == "recommendation" || notif.category == "guidance_update")
        }
        if touchesRecommendations {
            await applyAdvisorSlice(for: fieldID)
        }
    }

    /// Advice from an agronomist, newest first — the messages a person wrote, separated
    /// from automatic system notices.
    var expertAdvisories: [UserNotification] {
        notifications.filter { $0.isFromExpert }
    }

    var hasUnreadExpertAdvice: Bool {
        expertAdvisories.contains { !$0.isRead }
    }

    func markNotificationRead(_ notification: UserNotification) {
        Task {
            if let updated = try? await dataService.markNotificationRead(id: notification.id) {
                if let index = notifications.firstIndex(where: { $0.id == updated.id }) {
                    notifications[index] = updated
                    unreadNotificationsCount = notifications.filter { !$0.isRead }.count
                }
            }
        }
    }

    /// Clears the badge in one call. Without this a run of advisories had to be opened
    /// one at a time, which trains people to ignore the badge entirely.
    func markAllNotificationsRead() {
        Task {
            guard (try? await dataService.markAllNotificationsRead()) != nil else { return }
            await refreshNotifications()
        }
    }

    /// Polls the inbox continuously. Advice is time-sensitive — an irrigation
    /// call that arrives an hour late is worth much less than one that arrives now.
    private func pollNotifications() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(Self.notificationPollInterval * 1_000_000_000))
            if isAppActive, !Task.isCancelled {
                await refreshNotifications()
            }
        }
    }

    private func availabilityItems(from sources: DashboardSources) -> [DataAvailabilityItem] {
        let values: [(String, String, Date?, String?, Bool)] = [
            ("satellite", "Satellite", sources.satellite.lastUpdated, sources.satellite.message, sources.satellite.canRetry),
            ("soil", "Soil", sources.soil.lastUpdated, sources.soil.message, sources.soil.canRetry),
            ("weather", "Weather", sources.weather.lastUpdated, sources.weather.message, sources.weather.canRetry),
            ("uvi", "UV index", sources.uvi.lastUpdated, sources.uvi.message, sources.uvi.canRetry),
            ("sensors", "IoT sensors", sources.sensors.lastUpdated, sources.sensors.message, sources.sensors.canRetry),
        ]
        let states = [sources.satellite.availability, sources.soil.availability, sources.weather.availability, sources.uvi.availability, sources.sensors.availability]
        return zip(values, states).compactMap { value, state in
            if state == .available || (value.0 == "sensors" && state == .notConfigured) { return nil }
            return DataAvailabilityItem(id: value.0, title: value.1, status: state, lastUpdated: value.2, message: value.3, retryable: value.4)
        }
    }

    private func presentError(_ message: String) {
        errorMessage = message
        ToastMessageAutoDismiss.schedule(expectedMessage: message, currentMessage: { [weak self] in self?.errorMessage }, clearMessage: { [weak self] in self?.errorMessage = nil })
    }
}
