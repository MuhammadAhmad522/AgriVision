import UIKit
import SwiftUI

/// Owns the navigation flow for the Settings feature.
/// Keeping this separate prevents the DashboardCoordinator from becoming bloated
/// and strictly upholds the Single Responsibility Principle.
final class SettingsCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController

    private let authService: AuthService
    private let dataService: AgriDataService
    private let preferencesService: PreferencesService
    
    /// Called when the user signs out, ending the logged-in session.
    var onSignOut: (() -> Void)?
    
    /// Called when the user dismisses the settings screen to return to the dashboard.
    var onFinished: (() -> Void)?
    
    var onFieldsEmptied: (() -> Void)?
    var onActiveFieldChanged: (() -> Void)?

    init(
        navigationController: UINavigationController, 
        authService: AuthService, 
        dataService: AgriDataService, 
        preferencesService: PreferencesService
    ) {
        self.navigationController = navigationController
        self.authService = authService
        self.dataService = dataService
        self.preferencesService = preferencesService
    }

    func start() {
        let viewModel = SettingsViewModel(
            authService: authService,
            dataService: dataService,
            preferencesService: preferencesService
        )
        
        viewModel.onSignOut = { [weak self] in
            self?.onSignOut?()
        }
        
        viewModel.onFieldsEmptied = { [weak self] in
            self?.onFieldsEmptied?()
        }
        
        viewModel.onActiveFieldChanged = { [weak self] in
            self?.onActiveFieldChanged?()
        }
        
        let view = SettingsView(viewModel: viewModel)
        
        // Wrap the SwiftUI view in a hosting controller for UIKit navigation
        let hostingController = UIHostingController(rootView: view)
        
        // Push the settings screen onto the navigation stack
        navigationController.pushViewController(hostingController, animated: true)
    }
}
