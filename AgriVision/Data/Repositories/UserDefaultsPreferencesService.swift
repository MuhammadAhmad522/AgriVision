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
}
