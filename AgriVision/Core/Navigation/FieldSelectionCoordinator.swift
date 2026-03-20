import UIKit
import SwiftUI

/// Manages the flow for selecting and creating agricultural fields.
/// This includes the introductory "Add Field" screen and the interactive MapKit selection.
final class FieldSelectionCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController

    private let authService: AuthService
    
    /// Called when the user successfully defines their field and confirms.
    var onFieldConfirmed: (() -> Void)?
    
    /// Called if the user cancels the process.
    var onCancel: (() -> Void)?

    init(navigationController: UINavigationController, authService: AuthService) {
        self.navigationController = navigationController
        self.authService = authService
    }

    func start() {
        showIntro()
    }
    
    private func showIntro() {
        let viewModel = AddFieldIntroViewModel(authService: authService)
        
        viewModel.onAddFieldTapped = { [weak self] in
            self?.showMapSelection()
        }
        
        let view = AddFieldIntroView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: view)
        
        // Use setViewControllers to ensure this is the root of the current flow or just push
        navigationController.pushViewController(hostingController, animated: true)
    }
    
    private func showMapSelection() {
        let viewModel = FieldSelectionViewModel(authService: authService)
        
        viewModel.onConfirmField = { [weak self] in
            self?.onFieldConfirmed?()
        }
        
        viewModel.onCancel = { [weak self] in
            self?.onCancel?()
            self?.navigationController.popViewController(animated: true)
        }
        
        let view = FieldSelectionView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: view)
        
        // Hide navigation bar for the map as it has custom overlays
        navigationController.setNavigationBarHidden(true, animated: true)
        
        navigationController.pushViewController(hostingController, animated: true)
    }
}
