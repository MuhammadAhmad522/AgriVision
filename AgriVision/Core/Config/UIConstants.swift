import SwiftUI

/// Centralized layout constants to ensure consistency and avoid magic numbers.
enum UIConstants {
    enum Splash {
        /// How long (in seconds) the splash screen is displayed before transitioning.
        static let duration: TimeInterval = 2.5
    }

    enum Onboarding {
        static let blurredImageFrame: CGFloat = 420
        static let mainImageFrame: CGFloat = 320
        static let imageAreaHeight: CGFloat = 350
        static let blurredImageBlurRadius: CGFloat = 20
        static let blurredImageOpacity: Double = 0.9
        static let horizontalPadding: CGFloat = 24
        static let pageTransitionOffsetMultiplier: CGFloat = 0.45
        
        static let titleSize: CGFloat = 22
        static let mainTitleSize: CGFloat = 50
        static let descriptionSize: CGFloat = 18
    }
    
    enum Dashboard {
        static let sensorIconSize: CGFloat = 40
        static let cornerRadius: CGFloat = 12
    }

    enum Auth {
        /// Width used by form inputs, primary buttons, social buttons, and the OR divider.
        static let formWidth: CGFloat = 326
        /// Width of the glassmorphic card container.
        static let cardWidth: CGFloat = 371
        /// Corner radius of the glassmorphic card container.
        static let cardCornerRadius: CGFloat = 50
        /// Minimum height for the top and bottom spacers inside the scroll view.
        static let scrollSpacerMinLength: CGFloat = 60
        /// Top padding for the tab toggle inside the card.
        static let cardTopPadding: CGFloat = 25
        /// Horizontal padding applied to the card's inner content.
        static let cardHorizontalPadding: CGFloat = 22
        /// Height of the primary action button (Login / Register).
        static let primaryButtonHeight: CGFloat = 40
        /// Height of social authentication buttons.
        static let socialButtonHeight: CGFloat = 44
        /// Height of the text field input area.
        static let textFieldHeight: CGFloat = 40
    }
}
