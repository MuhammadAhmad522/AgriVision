import Foundation

protocol PreferencesService {
    var savedEmail: String? { get set }
    var activeFieldId: UUID? { get set }
    var dashboardRefreshInterval: TimeInterval { get set }
}
