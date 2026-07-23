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

    var dashboardRefreshInterval: TimeInterval {
        get {
            let stored = UserDefaults.standard.double(forKey: "dashboard_refresh_interval")
            return [15.0, 30.0, 60.0].contains(stored) ? stored : 30
        }
        set {
            let allowed = [15.0, 30.0, 60.0]
            UserDefaults.standard.set(allowed.contains(newValue) ? newValue : 30, forKey: "dashboard_refresh_interval")
        }
    }
}
