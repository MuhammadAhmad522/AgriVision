import Foundation

final class UserDefaultsPreferencesService: PreferencesService {
    func getSavedEmail() -> String? {
        return UserDefaults.standard.string(forKey: StorageKeys.savedEmail)
    }
    
    var savedEmail: String? {
        get {
            UserDefaults.standard.string(forKey: StorageKeys.savedEmail)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: StorageKeys.savedEmail)
        }
    }
    
    var activeFieldId: UUID? {
        get {
            guard let stringId = UserDefaults.standard.string(forKey: StorageKeys.activeFieldId) else { return nil }
            return UUID(uuidString: stringId)
        }
        set {
            UserDefaults.standard.set(newValue?.uuidString, forKey: StorageKeys.activeFieldId)
        }
    }

    // 5s is the live setting and the default: the ESP32 firmware samples and publishes on a
    // 5s cycle, so polling faster than this re-fetches rows that have not changed yet.
    static let allowedRefreshIntervals: [TimeInterval] = [5, 15, 30, 60]
    static let defaultRefreshInterval: TimeInterval = 5

    var dashboardRefreshInterval: TimeInterval {
        get {
            let stored = UserDefaults.standard.double(forKey: "dashboard_refresh_interval")
            return Self.allowedRefreshIntervals.contains(stored) ? stored : Self.defaultRefreshInterval
        }
        set {
            let resolved = Self.allowedRefreshIntervals.contains(newValue) ? newValue : Self.defaultRefreshInterval
            UserDefaults.standard.set(resolved, forKey: "dashboard_refresh_interval")
        }
    }
}
