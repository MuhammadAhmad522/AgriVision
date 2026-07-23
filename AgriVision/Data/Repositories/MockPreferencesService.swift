import Foundation

final class MockPreferencesService: PreferencesService {
    var savedEmail: String?
    var activeFieldId: UUID?
    var dashboardRefreshInterval: TimeInterval = 30
}
