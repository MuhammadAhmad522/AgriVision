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

        // Step 2: Wire the AuthViewModel's `onAuthComplete` callback to this coordinator's
        // `onFinished` closure. `AuthViewModel` is the single "auth finished" signal owner;
        // child ViewModels funnel their success events into it (DIP / MVVM-C).
        authViewModel.onAuthComplete = { [weak self] in self?.onFinished?() }

        // Step 3: Forward child-ViewModel success events into `AuthViewModel.authCompleted()`
        // so AuthViewModel remains the single point of authority for "user is authenticated".
        loginViewModel.onLoginSuccess = { [weak authViewModel] in authViewModel?.authCompleted() }
        signupViewModel.onSignupSuccess = { [weak authViewModel] in authViewModel?.authCompleted() }

        // Step 4: Inject all ViewModels into the View.
        let authView = AuthContainerView(
            viewModel: authViewModel,
            loginViewModel: loginViewModel,
            signupViewModel: signupViewModel
        )
        let hostingController = UIHostingController(rootView: authView)
        navigationController.setViewControllers([hostingController], animated: true)
    }
}
