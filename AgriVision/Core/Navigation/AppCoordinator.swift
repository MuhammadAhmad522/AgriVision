import UIKit
import SwiftUI

/**
 `AppCoordinator` is the root coordinator for the application.
 It manages the top-level app flow: Splash → Onboarding → Auth → Dashboard.
 
 It acts as the "boss" of the app, injecting necessary services (like Firebase) and handing off
 specific, screen-to-screen navigation to child coordinators (like AuthCoordinator).
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
    
    /// The authentication service handling user login/signup.
    private let authService: AuthService
    private let userProfileService: UserProfileService
    private let preferencesService: PreferencesService
    private let fieldSessionStore: FieldSessionStore

    init(
        window: UIWindow,
        onboardingStateService: OnboardingStateService,
        dataService: AgriDataService,
        authService: AuthService,
        userProfileService: UserProfileService,
        preferencesService: PreferencesService,
        fieldSessionStore: FieldSessionStore
    ) {
        self.window = window
        self.onboardingStateService = onboardingStateService
        self.dataService = dataService
        self.authService = authService
        self.userProfileService = userProfileService
        self.preferencesService = preferencesService
        self.fieldSessionStore = fieldSessionStore
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
            // Check if user is already logged in
            if authService.isUserLoggedIn {
                checkFieldsAndRoute()
            } else {
                showAuth()
            }
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
        let authCoordinator = AuthCoordinator(
            navigationController: navigationController,
            authService: authService,
            userProfileService: userProfileService,
            preferencesService: preferencesService
        )
        
        authCoordinator.onFinished = { [weak self, weak authCoordinator] in
            guard let self = self, let coordinator = authCoordinator else { return }
            
            // Remove the coordinator from our tracker.
            self.childCoordinators.removeAll { $0 === coordinator }
            
            // Now transition to the main dashboard.
            self.checkFieldsAndRoute()
        }
        
        childCoordinators.append(authCoordinator)
        authCoordinator.start()
    }
    
    private func checkFieldsAndRoute() {
        Task {
            do {
                try await fieldSessionStore.bootstrap()
                await MainActor.run {
                    if fieldSessionStore.fields.isEmpty {
                        showFieldSelection()
                    } else {
                        showMain()
                    }
                }
            } catch {
                await MainActor.run {
                    showBackendConnectionError(error)
                }
            }
        }
    }

    private func showBackendConnectionError(_ error: Error) {
        let view = BackendConnectionView(
            message: error.userFacingMessage,
            isRetrying: fieldSessionStore.isRefreshing,
            onRetry: { [weak self] in self?.checkFieldsAndRoute() },
            onSignOut: { [weak self] in
                guard let self else { return }
                try? self.authService.signOut()
                self.fieldSessionStore.clear()
                self.showAuth()
            }
        )
        navigationController.setViewControllers([UIHostingController(rootView: view)], animated: true)
    }
    
    private func showFieldSelection() {
        let fieldCoordinator = FieldSelectionCoordinator(
            navigationController: navigationController,
            authService: authService,
            dataService: dataService
        )
        
        fieldCoordinator.onFieldConfirmed = { [weak self, weak fieldCoordinator] in
            guard let self = self, let coordinator = fieldCoordinator else { return }
            self.childCoordinators.removeAll { $0 === coordinator }
            Task {
                try? await self.fieldSessionStore.refresh()
                await MainActor.run { self.showMain() }
            }
        }
        
        fieldCoordinator.onCancel = {
            // No-op: Map cancel pops back to AddFieldIntro screen within the same coordinator flow
        }

        fieldCoordinator.onSignOut = { [weak self, weak fieldCoordinator] in
            guard let self = self else { return }
            if let coordinator = fieldCoordinator {
                self.childCoordinators.removeAll { $0 === coordinator }
            }
            self.fieldSessionStore.clear()
            self.showAuth()
        }

        childCoordinators.append(fieldCoordinator)
        fieldCoordinator.start()
    }
    
    private func showMain() {
        let dashboardCoordinator = DashboardCoordinator(
            navigationController: navigationController,
            dataService: dataService,
            authService: authService,
            preferencesService: preferencesService,
            fieldSessionStore: fieldSessionStore
        )
        dashboardCoordinator.onSignOut = { [weak self] in
            // When sign out occurs in the dashboard, we unwind to the auth flow.
            self?.childCoordinators.removeAll { $0 === dashboardCoordinator }
            self?.fieldSessionStore.clear()
            self?.showAuth()
        }
        
        childCoordinators.append(dashboardCoordinator)
        dashboardCoordinator.start()
    }
}
