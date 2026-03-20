import UIKit
import SwiftUI

/// Owns the navigation flow for the Settings feature.
/// Keeping this separate prevents the DashboardCoordinator from becoming bloated
/// and strictly upholds the Single Responsibility Principle.
final class SettingsCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController

    private let authService: AuthService
    
    /// Called when the user signs out, ending the logged-in session.
    var onSignOut: (() -> Void)?
    
    /// Called when the user dismisses the settings screen to return to the dashboard.
    var onFinished: (() -> Void)?

    init(navigationController: UINavigationController, authService: AuthService) {
        self.navigationController = navigationController
        self.authService = authService
    }

    func start() {
        let viewModel = SettingsViewModel(authService: authService)
        
        viewModel.onSignOut = { [weak self] in
            self?.onSignOut?()
        }
        
        let view = SettingsView(viewModel: viewModel)
        
        // Wrap the SwiftUI view in a hosting controller for UIKit navigation
        let hostingController = UIHostingController(rootView: view)
        
        // Push the settings screen onto the navigation stack
        navigationController.pushViewController(hostingController, animated: true)
    }
}
