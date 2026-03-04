import Foundation

/// A data model representing a single page in the onboarding flow.
/// This struct defines the information needed to show one screen of the intro tutorial.
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
}

