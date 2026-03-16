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
        
        let view = DashboardView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: view)
        
        // Show the navigation bar for the dashboard
        navigationController.setNavigationBarHidden(false, animated: true)
        navigationController.navigationBar.prefersLargeTitles = true
        
        // Use push if we came from Intro, or setViewControllers if replacing
        // If we want to allow "Back" (unlikely for dashboard), use setViewControllers to reset stack
        navigationController.setViewControllers([hostingController], animated: true)
    }
}
