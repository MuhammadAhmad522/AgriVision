import UIKit
import SwiftUI

/// `DashboardCoordinator` owns the navigation flow for the Dashboard feature.
///
/// Extracting this from `AppCoordinator` satisfies the Single Responsibility Principle (SRP):
/// `AppCoordinator` is now only responsible for the top-level app flow (Splash → Onboarding → Auth → Dashboard),
/// while `DashboardCoordinator` owns everything that happens *inside* the Dashboard.
///
/// The injected `AgriDataService` satisfies the Dependency Inversion Principle (DIP): the
/// coordinator depends on a protocol abstraction rather than a concrete repository type.
final class DashboardCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController

    private let dataService: AgriDataService
    private let authService: AuthService
    
    var onSignOut: (() -> Void)?

    init(navigationController: UINavigationController, dataService: AgriDataService, authService: AuthService) {
        self.navigationController = navigationController
        self.dataService = dataService
        self.authService = authService
    }

    func start() {
        showAddFieldIntro()
    }
    
    private func showAddFieldIntro() {
        let viewModel = AddFieldIntroViewModel(authService: authService)
        viewModel.onAddFieldTapped = { [weak self] in
            // For now, proceed to dashboard when tapped (simulating flow)
            self?.showDashboard()
        }
        
        let view = AddFieldIntroView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: view)
        
        // Hide navigation bar as the design has a custom top bar
        navigationController.setNavigationBarHidden(true, animated: true)
        
        navigationController.setViewControllers([hostingController], animated: true)
    }

    private func showDashboard() {
        let viewModel = DashboardViewModel(dataService: dataService, authService: authService)
        viewModel.onSignOut = { [weak self] in
            self?.onSignOut?()
        }
        viewModel.onSettingsTap = { [weak self] in
            self?.showSettings()
        }
        
        let view = DashboardView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: view)
        
        // Show the navigation bar for the dashboard
        navigationController.setNavigationBarHidden(false, animated: true)
        navigationController.navigationBar.prefersLargeTitles = true
        
        // Use push if we came from Intro, or setViewControllers if replacing
        // If we want to allow "Back" (unlikely for dashboard), use setViewControllers to reset stack
        navigationController.setViewControllers([hostingController], animated: true)
    }

    private func showSettings() {
        let settingsCoordinator = SettingsCoordinator(navigationController: navigationController, authService: authService)
        
        settingsCoordinator.onSignOut = { [weak self] in
            self?.onSignOut?()
            // When signing out from settings, we want to pop everything
            self?.navigationController.popToRootViewController(animated: false)
        }
        
        settingsCoordinator.onFinished = { [weak self, weak settingsCoordinator] in
            guard let self = self, let coordinator = settingsCoordinator else { return }
            self.childCoordinators.removeAll { $0 === coordinator }
        }
        
        childCoordinators.append(settingsCoordinator)
        settingsCoordinator.start()
    }
}
