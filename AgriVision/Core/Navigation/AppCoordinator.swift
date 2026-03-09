import UIKit
import SwiftUI

/**
 `AppCoordinator` is the root coordinator for the application.
 Its sole responsibility is managing the top-level flow: Splash → Onboarding → Auth → Dashboard
 (with shortcuts that skip Onboarding or Auth when the user has already completed them).

 All dependencies are injected via the initializer (Dependency Inversion Principle).
 Concrete navigation for each feature is delegated to child coordinators (Single Responsibility Principle).
 */
final class AppCoordinator: Coordinator {

    // Conforming to the Coordinator protocol
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController

    /// The main window of the application where all user interface is drawn.
    private let window: UIWindow

    /// Abstracts read/write access to the "has seen onboarding" flag.
    /// Injected so the coordinator never touches `UserDefaults` directly (DIP).
    private let onboardingStateService: OnboardingStateService

    /// The data service supplied to child coordinators.
    /// Injected as a protocol so the real vs. mock implementation is chosen at the composition root (DIP).
    private let dataService: AgriDataService

    init(
        window: UIWindow,
        onboardingStateService: OnboardingStateService,
        dataService: AgriDataService
    ) {
        self.window = window
        self.onboardingStateService = onboardingStateService
        self.dataService = dataService
        self.navigationController = UINavigationController()
        // Hide the navigation bar by default for a cleaner, full-screen experience.
        self.navigationController.isNavigationBarHidden = true
    }

    /// Kicks off the app's UI by showing the splash screen and then routing to the correct flow.
    func start() {
        showSplash()

        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        // Use UIConstants.Splash.duration instead of a magic number.
        DispatchQueue.main.asyncAfter(deadline: .now() + UIConstants.Splash.duration) { [weak self] in
            self?.showOnboarding()
        }
    }

    // MARK: - Private routing

    private func showSplash() {
        let splashView = SplashView()
        let hostingController = UIHostingController(rootView: splashView)
        navigationController.setViewControllers([hostingController], animated: false)
    }

    private func showOnboarding() {
        if onboardingStateService.hasSeenOnboarding {
            // Onboarding already completed, but the user still needs to log in.
            showAuth()
            return
        }

        let onboardingCoordinator = OnboardingCoordinator(navigationController: navigationController)

        // Capture both weakly to avoid a retain cycle.
        onboardingCoordinator.onFinished = { [weak self, weak onboardingCoordinator] in
            guard let self = self, let coordinator = onboardingCoordinator else { return }

            self.onboardingStateService.markOnboardingComplete()
            self.childCoordinators.removeAll { $0 === coordinator }
            // Transition to the Auth flow instead of Main.
            self.showAuth()
        }

        childCoordinators.append(onboardingCoordinator)
        onboardingCoordinator.start()
    }
    /// Shows the authentication flow (Login/Signup).
    private func showAuth() {
        let authCoordinator = AuthCoordinator(navigationController: navigationController)
        
        authCoordinator.onFinished = { [weak self, weak authCoordinator] in
            guard let self = self, let coordinator = authCoordinator else { return }
            
            // Remove the coordinator from our tracker.
            self.childCoordinators.removeAll { $0 === coordinator }
            
            // Now transition to the main dashboard.
            self.showMain()
        }
        
        childCoordinators.append(authCoordinator)
        authCoordinator.start()
    }
    
    private func showMain() {
        let dashboardCoordinator = DashboardCoordinator(
            navigationController: navigationController,
            dataService: dataService
        )
        childCoordinators.append(dashboardCoordinator)
        dashboardCoordinator.start()
    }
}
