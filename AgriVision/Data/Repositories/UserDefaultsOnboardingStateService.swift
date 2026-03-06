import Foundation

/// Concrete `OnboardingStateService` backed by `UserDefaults`.
/// Keeping `UserDefaults` behind this class means the coordinator never touches
/// `UserDefaults.standard` directly, honoring the Dependency Inversion Principle.
final class UserDefaultsOnboardingStateService: OnboardingStateService {

    private let defaults: UserDefaults
    private let key = "hasSeenOnboarding"

    /// - Parameter defaults: The `UserDefaults` store to use. Defaults to `.standard`
    ///   so production code works without extra wiring while tests can supply an isolated suite.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasSeenOnboarding: Bool {
        defaults.bool(forKey: key)
    }

    func markOnboardingComplete() {
        defaults.set(true, forKey: key)
    }
}
