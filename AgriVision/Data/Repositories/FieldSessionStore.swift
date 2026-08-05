import Foundation
import Combine

@MainActor
final class FieldSessionStore: ObservableObject {
    @Published var fields: [Field] = []
    @Published var activeFieldId: UUID?
    @Published var activeFieldLimit: Int = 5
    @Published var isRefreshing = false
    @Published var lastError: Error?

    private let dataService: AgriDataService
    private let authService: AuthService

    init(dataService: AgriDataService, authService: AuthService) {
        self.dataService = dataService
        self.authService = authService
    }

    var activeField: Field? {
        fields.first(where: { $0.id == activeFieldId })
    }

    var hasReachedLimit: Bool { fields.count >= activeFieldLimit }

    func bootstrap() async throws {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let session = try await dataService.bootstrapSession()
            activeFieldLimit = session.activeFieldLimit
            apply(session.fields)
            lastError = nil
        } catch {
            lastError = error
            throw error
        }
    }

    func refresh() async throws {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            apply(try await dataService.fetchFields(includeArchived: false))
            lastError = nil
        } catch {
            lastError = error
            throw error
        }
    }

    func select(_ id: UUID) {
        guard fields.contains(where: { $0.id == id }) else { return }
        activeFieldId = id
        UserDefaults.standard.set(id.uuidString, forKey: persistenceKey)
    }

    func selectPrevious() {
        guard let activeFieldId, let index = fields.firstIndex(where: { $0.id == activeFieldId }), index > 0 else { return }
        select(fields[index - 1].id)
    }

    func selectNext() {
        guard let activeFieldId, let index = fields.firstIndex(where: { $0.id == activeFieldId }), index < fields.count - 1 else { return }
        select(fields[index + 1].id)
    }

    func merge(_ field: Field) {
        guard let index = fields.firstIndex(where: { $0.id == field.id }), field.status == "active" else { return }
        fields[index] = field
    }

    func deleteActiveField() async throws {
        guard let activeFieldId else { return }
        try await dataService.deleteField(id: activeFieldId)
        try await refresh()
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: persistenceKey)
        fields = []
        activeFieldId = nil
        lastError = nil
    }

    private func apply(_ newFields: [Field]) {
        fields = newFields.filter { $0.status == "active" }
        let persisted = UserDefaults.standard.string(forKey: persistenceKey).flatMap(UUID.init(uuidString:))
        if let activeFieldId, fields.contains(where: { $0.id == activeFieldId }) {
            select(activeFieldId)
        } else if let persisted, fields.contains(where: { $0.id == persisted }) {
            select(persisted)
        } else if let first = fields.first {
            select(first.id)
        } else {
            activeFieldId = nil
            UserDefaults.standard.removeObject(forKey: persistenceKey)
        }
    }

    private var persistenceKey: String {
        "agrivision.active-field.\(authService.currentUserID ?? "signed-out")"
    }
}
