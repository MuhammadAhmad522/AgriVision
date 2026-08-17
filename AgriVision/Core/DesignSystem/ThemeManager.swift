import SwiftUI
import UIKit

public final class ThemeManager {
    public static let shared = ThemeManager()
    
    @AppStorage("appThemePreference") public var themePreference: String = "System" {
        didSet {
            applyTheme()
        }
    }
    
    private init() {}
    
    public func applyTheme() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        switch themePreference {
        case "Light":
            window.overrideUserInterfaceStyle = .light
        case "Dark":
            window.overrideUserInterfaceStyle = .dark
        default:
            window.overrideUserInterfaceStyle = .unspecified
        }
    }
}
