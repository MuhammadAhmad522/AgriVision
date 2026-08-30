import Combine
import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var recommendations: [FieldRecommendation] = []
    @Published var seasonMemory: SeasonMemory?
    @Published var advisorStatus = "pending"
    @Published var advisorMessage: String?
    @Published var advisorDataQuality: String?
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

    let fieldSessionStore: FieldSessionStore
    let dataService: AgriDataService
    private let authService: AuthService
    private let preferencesService: PreferencesService
    private var cancellables: Set<AnyCancellable> = []
    private var dashboardRequestToken: UUID?

    // Matches the backend's own external-data scan cadence (AGRO_WORKER_SCAN_SECONDS in
    // AgriVision-Backend). Polling faster than the backend itself checks for new satellite/
    // weather/soil data or reconsiders AI recommendations cannot surface anything newer —
    // it would just re-download unchanged satellite images and recommendation text.
    private static let fullDashboardRefreshInterval: TimeInterval = 300

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
        async let sensors: Void = pollSensorReadings()
        async let dashboard: Void = pollFullDashboard()
        _ = await (sensors, dashboard)
    }

    private func pollSensorReadings() async {
        while !Task.isCancelled {
            await refreshSensorReadingsOnly()
            try? await Task.sleep(for: .seconds(preferencesService.dashboardRefreshInterval))
        }
    }

    private func pollFullDashboard() async {
        while !Task.isCancelled {
            await refreshData()
            try? await Task.sleep(for: .seconds(Self.fullDashboardRefreshInterval))
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
            readings = snapshot.sources.sensors.data ?? []
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

    func refreshRecommendations() async {
        guard let fieldID = fieldSessionStore.activeFieldId else { return }
        isRefreshingAI = true
        defer { isRefreshingAI = false }
        // The backend runs the actual re-analysis as an async background job and returns
        // immediately with whatever recommendations already existed — a single refetch right
        // after would almost always show stale advice with a false "updated" message. Poll
        // until a recommendation created after this trigger actually shows up (or the run
        // fails), bounded so this can't hang forever.
        let triggeredAt = Date()
        do {
            advisorStatus = "pending"
            advisorMessage = "AI is reviewing the latest field evidence."
            try await dataService.refreshRecommendations(for: fieldID)
            guard fieldID == fieldSessionStore.activeFieldId else { return }
            for attempt in 0..<8 {
                if attempt > 0 { try? await Task.sleep(for: .seconds(3)) }
                await refreshData()
                guard fieldID == fieldSessionStore.activeFieldId else { return }
                if recommendations.contains(where: { $0.createdAt > triggeredAt }) {
                    successMessage = "Advice updated with latest insights."
                    ToastMessageAutoDismiss.schedule(expectedMessage: successMessage ?? "", currentMessage: { [weak self] in self?.successMessage }, clearMessage: { [weak self] in self?.successMessage = nil })
                    return
                }
                if advisorStatus == "unavailable" { return } // run failed — refreshData() already surfaced the real error
            }
            presentError("Still processing — check back in a moment.")
        } catch {
            guard fieldID == fieldSessionStore.activeFieldId else { return }
            advisorStatus = "unavailable"
            advisorMessage = error.userFacingMessage
            presentError(error.userFacingMessage)
        }
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
