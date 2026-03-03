import SwiftUI

/// Centralized layout constants to ensure consistency and avoid magic numbers.
enum UIConstants {
    enum Onboarding {
        static let blurredImageFrame: CGFloat = 420
        static let mainImageFrame: CGFloat = 320
        static let imageAreaHeight: CGFloat = 400
        static let blurredImageBlurRadius: CGFloat = 20
        static let blurredImageOpacity: Double = 0.9
        static let horizontalPadding: CGFloat = 24
        static let pageTransitionOffsetMultiplier: CGFloat = 0.45
        
        static let titleSize: CGFloat = 22
        static let mainTitleSize: CGFloat = 60
        static let descriptionSize: CGFloat = 18
    }
    
    enum Dashboard {
        static let sensorIconSize: CGFloat = 40
        static let cornerRadius: CGFloat = 12
    }
}
