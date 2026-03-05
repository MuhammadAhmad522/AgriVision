import Foundation
import CoreGraphics

/// A data model representing a single page in the onboarding flow.
/// This struct defines both the content **and** its per-page layout configuration so
/// that `OnboardingPageView` never has to inspect image names or carry layout logic.
struct OnboardingPage: Identifiable {
    // Unique ID for each page, used by SwiftUI to distinguish between items in a list or TabView
    let id = UUID()
    
    // The main title text shown on the page (e.g. "AgriVision")
    let title: String
    
    // An optional longer description text (currently unused in the default pages)
    let description: String
    
    // The name of the main image file from the Assets folder
    let imageName: String
    
    // An optional name for a blurred version of the background image
    let blurredImageName: String?
    
    // A check to see if we should use a system icon (SF Symbols) or a custom image
    let isSystemImage: Bool
    
    // MARK: - Per-page layout configuration
    
    /// Scale multiplier applied to the main image frame (relative to `UIConstants.Onboarding.mainImageFrame`).
    let imageScale: CGFloat
    
    /// Vertical offset applied to the main image.
    let imageYOffset: CGFloat
    
    /// Scale multiplier applied to the blurred background image frame.
    let blurredImageScale: CGFloat
    
    /// Horizontal offset applied to the blurred background image.
    let blurredImageXOffset: CGFloat
    
    /// Vertical offset applied to the blurred background image.
    let blurredImageYOffset: CGFloat
    
    /// Convenience initializer with sensible defaults so existing call-sites that don't need
    /// custom layout don't have to supply these parameters.
    init(
        title: String,
        description: String,
        imageName: String,
        blurredImageName: String? = nil,
        isSystemImage: Bool = false,
        imageScale: CGFloat = 1.0,
        imageYOffset: CGFloat = 0,
        blurredImageScale: CGFloat = 1.0,
        blurredImageXOffset: CGFloat = -50,
        blurredImageYOffset: CGFloat = 30
    ) {
        self.title = title
        self.description = description
        self.imageName = imageName
        self.blurredImageName = blurredImageName
        self.isSystemImage = isSystemImage
        self.imageScale = imageScale
        self.imageYOffset = imageYOffset
        self.blurredImageScale = blurredImageScale
        self.blurredImageXOffset = blurredImageXOffset
        self.blurredImageYOffset = blurredImageYOffset
    }
}

