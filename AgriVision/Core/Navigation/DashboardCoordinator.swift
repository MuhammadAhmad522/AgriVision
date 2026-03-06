import UIKit
import SwiftUI

/// `DashboardCoordinator` owns the navigation flow for the Dashboard feature.
///
/// Extracting this from `AppCoordinator` satisfies the Single Responsibility Principle (SRP):
/// `AppCoordinator` is now only responsible for the top-level app flow (Splash → Onboarding → Dashboard),
/// while `DashboardCoordinator` owns everything that happens *inside* the Dashboard.
///
/// The injected `AgriDataService` satisfies the Dependency Inversion Principle (DIP): the
/// coordinator depends on a protocol abstraction rather than a concrete repository type.
final class DashboardCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController

    private let dataService: AgriDataService

    init(navigationController: UINavigationController, dataService: AgriDataService) {
        self.navigationController = navigationController
        self.dataService = dataService
    }

    func start() {
        let viewModel = DashboardViewModel(dataService: dataService)
        let view = DashboardView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: view)
        navigationController.setViewControllers([hostingController], animated: true)
    }
}
