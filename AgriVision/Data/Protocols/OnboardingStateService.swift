import Foundation

/// Abstracts read/write access to the "has seen onboarding" flag.
/// Using a protocol here satisfies the Dependency Inversion Principle (DIP):
/// high-level modules (AppCoordinator) depend on this abstraction, not on
/// `UserDefaults` directly, making the coordinator independently testable.
protocol OnboardingStateService: AnyObject {
    /// Returns `true` if the user has already completed the onboarding flow.
    var hasSeenOnboarding: Bool { get }

    /// Persists the fact that the user has completed onboarding.
    func markOnboardingComplete()
}
