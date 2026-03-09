import UIKit
import SwiftUI

/// Coordinator responsible for managing the authentication flow.
///
/// The Coordinator is the sole place where concrete ViewModel instances are created
/// and dependencies (callbacks) are injected — satisfying both the Dependency Inversion
/// Principle and MVVM-C's rule that Views/ViewModels must not know about Coordinators.
final class AuthCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController

    /// Closure called when the authentication process is finished (e.g., user logged in).
    var onFinished: (() -> Void)?

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {
        // Step 1: Create the ViewModels.
        let authViewModel = AuthViewModel()
        let loginViewModel = LoginViewModel()
        let signupViewModel = SignupViewModel()

        // Step 2: Wire auth-complete signals from child ViewModels to this coordinator's
        // `onFinished` closure. Neither ViewModel references the Coordinator (DIP / MVVM-C).
        loginViewModel.onLoginSuccess = { [weak self] in self?.onFinished?() }
        signupViewModel.onSignupSuccess = { [weak self] in self?.onFinished?() }

        // Step 3: Inject all ViewModels into the View.
        let authView = AuthContainerView(
            viewModel: authViewModel,
            loginViewModel: loginViewModel,
            signupViewModel: signupViewModel
        )
        let hostingController = UIHostingController(rootView: authView)
        navigationController.setViewControllers([hostingController], animated: true)
    }
}
