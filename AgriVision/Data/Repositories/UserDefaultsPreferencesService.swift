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
            if let email = newValue {
                UserDefaults.standard.set(email, forKey: StorageKeys.savedEmail)
            } else {
                UserDefaults.standard.removeObject(forKey: StorageKeys.savedEmail)
            }
        }
    }
}
