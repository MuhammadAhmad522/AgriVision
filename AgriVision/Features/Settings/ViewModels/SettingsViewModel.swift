import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var fields: [Field] = []
    @Published private(set) var activeFieldId: UUID?
    @Published private(set) var sensors: [FieldSensor] = []
    @Published private(set) var sensorStatus = "not_configured"
    @Published private(set) var satelliteStatus = "pending"
    @Published private(set) var profileName: String
    @Published private(set) var accountEmail: String
    @Published private(set) var isGoogleLinked: Bool
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var isPairingSensor = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var refreshInterval: TimeInterval

    let title = "Settings"

    private let authService: AuthService
    private let dataService: AgriDataService
    private var preferencesService: PreferencesService
    private let fieldSessionStore: FieldSessionStore?
    private var cancellables: Set<AnyCancellable> = []

    var onSignOut: (() -> Void)?
    var onFieldsEmptied: (() -> Void)?
    var onActiveFieldChanged: (() -> Void)?

    var accountName: String { profileName.isEmpty ? "AgriVision User" : profileName }
    var currentFieldName: String { activeField?.name ?? "No active field" }
    var activeField: Field? { fields.first(where: { $0.id == activeFieldId }) }
    var canLinkGoogle: Bool { !isGoogleLinked }
    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
    var satelliteSummary: String {
        guard let field = activeField else { return "No active field" }
        if let updated = field.lastSatelliteSync {
            return "\(satelliteStatus.capitalized) · \(updated.formatted(.relative(presentation: .named)))"
        }
        return satelliteStatus.capitalized
    }
    var sensorSummary: String {
        if sensors.isEmpty { return "Optional · Not connected" }
        return "\(sensors.count) connected · \(sensorStatus.capitalized)"
    }

    init(
        authService: AuthService,
        dataService: AgriDataService,
        preferencesService: PreferencesService,
        fieldSessionStore: FieldSessionStore? = nil
    ) {
        self.authService = authService
        self.dataService = dataService
        self.preferencesService = preferencesService
        self.fieldSessionStore = fieldSessionStore
        profileName = authService.currentUserDisplayName ?? ""
        accountEmail = authService.currentUserEmail ?? "Email unavailable"
        isGoogleLinked = authService.isGoogleProviderLinked
        refreshInterval = preferencesService.dashboardRefreshInterval
        activeFieldId = fieldSessionStore?.activeFieldId ?? preferencesService.activeFieldId

        fieldSessionStore?.$fields
            .sink { [weak self] fields in self?.fields = fields }
            .store(in: &cancellables)
        fieldSessionStore?.$activeFieldId
            .removeDuplicates()
            .sink { [weak self] id in
                guard let self else { return }
                activeFieldId = id
                Task { await self.refreshIntegrationStatus() }
            }
            .store(in: &cancellables)

        Task { await refreshAll() }
    }

    func refreshAll() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            if let fieldSessionStore {
                try await fieldSessionStore.refresh()
                fields = fieldSessionStore.fields
                activeFieldId = fieldSessionStore.activeFieldId
            } else {
                fields = try await dataService.fetchFields()
                if activeFieldId == nil, let first = fields.first { selectField(first.id) }
            }
            await refreshIntegrationStatus()
        } catch {
            presentError("Could not refresh settings: \(error.userFacingMessage)")
        }
    }

    func selectField(_ id: UUID) {
        guard fields.contains(where: { $0.id == id }) else { return }
        if let fieldSessionStore {
            fieldSessionStore.select(id)
        } else {
            preferencesService.activeFieldId = id
        }
        activeFieldId = id
        onActiveFieldChanged?()
        Task { await refreshIntegrationStatus() }
    }

    func setRefreshInterval(_ interval: TimeInterval) {
        let allowed: [TimeInterval] = [15, 30, 60]
        let resolved = allowed.contains(interval) ? interval : 30
        refreshInterval = resolved
        preferencesService.dashboardRefreshInterval = resolved
        presentSuccess("Dashboard refresh updated.")
    }

    func updateDisplayName(_ proposedName: String) async -> Bool {
        let normalized = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...80).contains(normalized.count), !normalized.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            presentError("Enter a name between 2 and 80 characters.")
            return false
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.updateDisplayName(normalized)
            profileName = normalized
            presentSuccess("Profile updated.")
            return true
        } catch {
            presentError(error.userFacingMessage)
            return false
        }
    }

    func pairAndAssignSensor(deviceID: String, name: String) async -> Bool {
        guard let fieldID = activeFieldId else {
            presentError("Select a field before pairing a sensor.")
            return false
        }
        let code = deviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let sensorName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._:-"))
        guard (3...100).contains(code.count), code.unicodeScalars.allSatisfy(allowed.contains) else {
            presentError("Enter a valid ESP32 pairing code.")
            return false
        }
        guard (2...100).contains(sensorName.count) else {
            presentError("Enter a sensor name between 2 and 100 characters.")
            return false
        }

        isPairingSensor = true
        defer { isPairingSensor = false }
        do {
            _ = try await dataService.pairSensor(deviceId: code)
            try await dataService.assignSensor(
                SensorConfig(deviceId: code, name: sensorName, sensorType: "esp32_multi_sensor"),
                to: fieldID
            )
            await refreshIntegrationStatus()
            presentSuccess("Sensor paired with \(currentFieldName).")
            return true
        } catch {
            presentError(error.userFacingMessage)
            return false
        }
    }

    func deleteField(_ id: UUID) {
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await dataService.deleteField(id: id)
                if let fieldSessionStore {
                    try await fieldSessionStore.refresh()
                    fields = fieldSessionStore.fields
                    activeFieldId = fieldSessionStore.activeFieldId
                } else {
                    fields.removeAll { $0.id == id }
                    if activeFieldId == id {
                        activeFieldId = fields.first?.id
                        preferencesService.activeFieldId = activeFieldId
                    }
                }
                if fields.isEmpty { onFieldsEmptied?() }
                await refreshIntegrationStatus()
                presentSuccess("Field permanently deleted.")
            } catch {
                presentError("Could not delete field: \(error.userFacingMessage)")
            }
        }
    }

    func linkGoogleAccount() {
        guard canLinkGoogle else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await authService.linkGoogleAccount()
                isGoogleLinked = true
                presentSuccess("Google account linked.")
            } catch {
                presentError(error.userFacingMessage)
            }
        }
    }

    func signOut() {
        do {
            try authService.signOut()
            fieldSessionStore?.clear()
            onSignOut?()
        } catch {
            presentError(error.userFacingMessage)
        }
    }

    private func refreshIntegrationStatus() async {
        guard let fieldID = activeFieldId else {
            sensors = []
            sensorStatus = "not_configured"
            satelliteStatus = "pending"
            return
        }

        do {
            sensors = try await dataService.fetchSensors(for: fieldID)
        } catch {
            sensors = []
            sensorStatus = "unavailable"
        }
        do {
            let dashboard = try await dataService.fetchDashboard(for: fieldID)
            guard fieldID == activeFieldId else { return }
            sensorStatus = dashboard.sources.sensors.status
            satelliteStatus = dashboard.sources.satellite.status
            fieldSessionStore?.merge(dashboard.field)
        } catch {
            sensorStatus = sensors.isEmpty ? "not_configured" : "unavailable"
            satelliteStatus = activeField?.agroStatus ?? "unavailable"
        }
    }

    private func presentError(_ message: String) {
        errorMessage = message
        successMessage = nil
        ToastMessageAutoDismiss.schedule(
            expectedMessage: message,
            currentMessage: { self.errorMessage },
            clearMessage: { self.errorMessage = nil }
        )
    }

    private func presentSuccess(_ message: String) {
        successMessage = message
        errorMessage = nil
        ToastMessageAutoDismiss.schedule(
            expectedMessage: message,
            currentMessage: { self.successMessage },
            clearMessage: { self.successMessage = nil }
        )
    }
}
