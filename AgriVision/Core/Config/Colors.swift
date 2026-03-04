import SwiftUI

// Central color palette to avoid scattering hex values across views.
enum AppColors {
    static let charcoalGreen = Color(hex: 0x3D6D40)
    static let mediumGreen = Color(hex: 0x6A8E4E)
    static let limeGreen = Color(hex: 0xB0D182)
    static let cream = Color(hex: 0xF4F1EA)
    
}

private extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let red = Double((hex & 0xFF0000) >> 16) / 255.0
        let green = Double((hex & 0x00FF00) >> 8) / 255.0
        let blue = Double(hex & 0x0000FF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
