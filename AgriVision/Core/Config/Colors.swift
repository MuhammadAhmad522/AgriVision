import SwiftUI

// Central color palette to avoid scattering hex values across views.
enum AppColors {
    static let charcoalGreen = Color(hex: "3D6D40")
    static let mediumGreen = Color(hex: "6A8E4E")
    static let limeGreen = Color(hex: "B0D182")
    static let cream = Color(hex: "F4F1EA")
    
    // Auth specific naming (aliases or additional)
    static let authGreen = charcoalGreen
    static let authLightGreen = limeGreen
    static let authDarkGreen = mediumGreen
    static let authCream = cream
    static let authPlaceholder = Color(hex: "B3B3B3")
    static let authBorder = Color(hex: "D9D9D9")
    static let authInputBorder = limeGreen
}

extension Color {
    // Auth aliases for direct Color access if needed
    static let authGreen = AppColors.authGreen
    static let authLightGreen = AppColors.authLightGreen
    static let authDarkGreen = AppColors.authDarkGreen
    static let authCream = AppColors.authCream
    static let authPlaceholder = AppColors.authPlaceholder
    static let authBorder = AppColors.authBorder
    static let authInputBorder = AppColors.authInputBorder

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // Support for UInt32 hex if still needed by original code
    init(hex: UInt32, alpha: Double = 1.0) {
        let red = Double((hex & 0xFF0000) >> 16) / 255.0
        let green = Double((hex & 0x00FF00) >> 8) / 255.0
        let blue = Double(hex & 0x0000FF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension LinearGradient {
    static let authPrimaryGradient = LinearGradient(
        gradient: Gradient(colors: [AppColors.authDarkGreen, AppColors.authLightGreen]),
        startPoint: .bottom,
        endPoint: .top
    )
    
    static let authTabSelection = LinearGradient(
        gradient: Gradient(colors: [AppColors.authDarkGreen, AppColors.authLightGreen]),
        startPoint: .top,
        endPoint: .bottom
    )
}
