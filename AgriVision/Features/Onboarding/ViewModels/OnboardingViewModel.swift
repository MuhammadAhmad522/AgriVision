import SwiftUI
import Combine

/**
 `OnboardingViewModel` handles the logic and state for the onboarding experience.
 By moving this out of the View, we adhere to the Single Responsibility Principle (SRP).
 */
class OnboardingViewModel: ObservableObject {
    // MARK: - Published State
    
    /// Keeps track of which page is currently being shown.
    @Published var currentPage = 0
    
    /// Tracks the continuous scroll offset as the user swipes.
    @Published var scrollOffset: CGFloat = 0
    
    /// A flag to prevent preference updates from fighting manual animation during programmatic changes.
    @Published var isProgrammaticChange = false
    
    /// Stores the actual width of the onboarding container for accurate math.
    var containerWidth: CGFloat = UIScreen.main.bounds.width
    
    // MARK: - Data
    
    /// Our list of pages. Layout configuration is stored in the model so that
    /// `OnboardingPageView` does not need to compare image names to decide sizing/offsets.
    let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "AgriVision",
            description: "",
            imageName: "onboarding_leaf",
            blurredImageName: "onboarding_leaf_blurred",
            isSystemImage: false,
            imageScale: 1.0,
            imageYOffset: 0,
            blurredImageScale: 1.0,
            blurredImageXOffset: -50,
            blurredImageYOffset: 30
        ),
        OnboardingPage(
            title: "Map Your Fields.\nGet Smart Alerts and AI Insights.",
            description: "",
            imageName: "onboarding_leaf_2",
            blurredImageName: "onboarding_leaf_2_blurred",
            isSystemImage: false,
            imageScale: 1.15,
            imageYOffset: -40,
            blurredImageScale: 1.15,
            blurredImageXOffset: -20,
            blurredImageYOffset: 40
        ),
        OnboardingPage(
            title: "Analyze soil, crop health, and field conditions using advanced satellite, IoT sensor and AI technology.",
            description: "",
            imageName: "onboarding_image_3",
            blurredImageName: "onboarding_image_3_blurred",
            isSystemImage: false,
            imageScale: 1.0,
            imageYOffset: 0,
            blurredImageScale: 1.0,
            blurredImageXOffset: 10,
            blurredImageYOffset: 60
        )
    ]
    
    // MARK: - Actions
    
    /// Handles the "Next" (or finish) button logic.
    func handleNextAction(onComplete: @escaping () -> Void) {
        if currentPage < pages.count - 1 {
            isProgrammaticChange = true
            
            // Move to the next page with a synchronized animation.
            withAnimation(.easeInOut(duration: 0.5)) {
                currentPage += 1
                scrollOffset = -CGFloat(currentPage) * containerWidth
            }
            
            // Reset the flag after the animation settles.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.isProgrammaticChange = false
            }
        } else {
            onComplete()
        }
    }
    
    /// Logic for updating scroll offset based on geometry preference changes.
    func handlePreferenceChange(dictionary: [Int: CGFloat]) {
        // Skip updates during programmatic animations to avoid "jitter".
        guard !isProgrammaticChange else { return }
        
        // Calculate the global scroll offset using a deterministic anchor.
        if let (index, minX) = dictionary.min(by: { $0.key < $1.key }) {
            scrollOffset = minX - (CGFloat(index) * containerWidth)
        }
    }
}
