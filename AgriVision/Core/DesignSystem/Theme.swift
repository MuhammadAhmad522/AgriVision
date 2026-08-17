import SwiftUI

/// Global Design System configuration
public enum Theme {
    
    // Helper for dynamic colors
    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        return Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? dark : light
        })
    }
    
    // MARK: - Colors
    public enum Colors {
        // Original Brand Colors
        private static let charcoalGreen = UIColor(red: 0x3D/255.0, green: 0x6D/255.0, blue: 0x40/255.0, alpha: 1.0)
        private static let mediumGreen = UIColor(red: 0x6A/255.0, green: 0x8E/255.0, blue: 0x4E/255.0, alpha: 1.0)
        private static let limeGreen = UIColor(red: 0xB0/255.0, green: 0xD1/255.0, blue: 0x82/255.0, alpha: 1.0)
        private static let cream = UIColor(red: 0xF4/255.0, green: 0xF1/255.0, blue: 0xEA/255.0, alpha: 1.0)
        
        /// The main brand color
        public static let primary = Color(charcoalGreen)
        public static let primaryLight = Color(limeGreen)
        public static let primaryMedium = Color(mediumGreen)
        public static let creamColor = Color(cream)
        
        /// Background colors
        public static let background = dynamicColor(light: cream, dark: UIColor(white: 0.1, alpha: 1.0))
        public static let surface = dynamicColor(light: .white, dark: UIColor(white: 0.15, alpha: 1.0))
        public static let surfaceHighlight = dynamicColor(light: UIColor(white: 0.95, alpha: 1.0), dark: UIColor(white: 0.2, alpha: 1.0))
        
        /// Text colors
        public static let textPrimary = dynamicColor(
            light: charcoalGreen,
            dark: cream
        )
        public static let textSecondary = dynamicColor(
            light: mediumGreen,
            dark: limeGreen
        )
        
        /// Functional colors
        public static let success = Color.green
        public static let warning = Color.orange
        public static let error = Color.red
    }
    
    // MARK: - Gradients
    public enum Gradients {
        /// A premium glassmorphism overlay gradient
        public static let glassOverlay = LinearGradient(
            colors: [
                Color.white.opacity(0.15),
                Color.white.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        /// Brand gradient for prominent buttons or headers
        public static let brandGradient = LinearGradient(
            colors: [Colors.primary, Colors.primaryLight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Spacing
    public enum Spacing {
        public static let xxSmall: CGFloat = 4
        public static let xSmall: CGFloat = 8
        public static let small: CGFloat = 12
        public static let medium: CGFloat = 16
        public static let large: CGFloat = 24
        public static let xLarge: CGFloat = 32
        public static let xxLarge: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    public enum Radius {
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 16
        public static let large: CGFloat = 24
        public static let pill: CGFloat = 999
    }
    
    // MARK: - Shadows
    public enum Shadows {
        /// A soft, elegant shadow for cards
        public static let soft = Color.black.opacity(0.1)
        /// A pronounced glow for active primary elements
        public static let primaryGlow = Colors.primary.opacity(0.3)
    }
}
