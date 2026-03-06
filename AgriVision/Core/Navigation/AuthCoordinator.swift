import UIKit
import SwiftUI

/// Coordinator responsible for managing the authentication flow.
class AuthCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController
    
    /// Closure called when the authentication process is finished (e.g., user logged in).
    var onFinished: (() -> Void)?
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    func start() {
        let authView = AuthContainerView()
        let hostingController = UIHostingController(rootView: authView)
        
        // Use setViewControllers to ensure this is the only view in the stack for this coordinator
        navigationController.setViewControllers([hostingController], animated: true)
    }
}
