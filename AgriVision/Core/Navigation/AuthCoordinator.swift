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

    private let authService: AuthService
    private let userProfileService: UserProfileService
    private let preferencesService: PreferencesService

    /// Closure called when the authentication process is finished (e.g., user logged in).
    var onFinished: (() -> Void)?

    init(
        navigationController: UINavigationController,
        authService: AuthService,
        userProfileService: UserProfileService,
        preferencesService: PreferencesService
    ) {
        self.navigationController = navigationController
        self.authService = authService
        self.userProfileService = userProfileService
        self.preferencesService = preferencesService
    }

    func start() {
        // Step 1: Create the ViewModels.
        let authViewModel = AuthViewModel()
        let loginViewModel = LoginViewModel(authService: authService, preferencesService: preferencesService)
        let signupViewModel = SignupViewModel(authService: authService, userProfileService: userProfileService)

        // Step 2: Wire the AuthViewModel's `onAuthComplete` callback to this coordinator's
        // `onFinished` closure.
        authViewModel.onAuthComplete = { [weak self] in self?.onFinished?() }

        // Step 3: Forward child-ViewModel success events.
        loginViewModel.onLoginSuccess = { [weak authViewModel] in authViewModel?.authCompleted() }
        loginViewModel.onRequireVerification = { [weak self] in
            self?.showVerificationScreen()
        }
        loginViewModel.onForgotPassword = { [weak self] in
            self?.showForgotPassword()
        }
        
        // Handle Google Sign-in Success (skip verification)
        signupViewModel.onSignupAutoLogin = { [weak authViewModel] in authViewModel?.authCompleted() }
        
        // Handle Email Signup Success (show verification screen)
        signupViewModel.onRequireVerification = { [weak self] in
            self?.showVerificationScreen()
        }

        // Step 4: Inject all ViewModels into the View.
        let authView = AuthContainerView(
            viewModel: authViewModel,
            loginViewModel: loginViewModel,
            signupViewModel: signupViewModel
        )
        let hostingController = UIHostingController(rootView: authView)
        
        // Hide the navigation bar for the auth flow
        navigationController.setNavigationBarHidden(true, animated: true)
        
        navigationController.setViewControllers([hostingController], animated: true)
    }
    
    private func showVerificationScreen() {
        let verifyViewModel = VerifyEmailViewModel(authService: authService)
        verifyViewModel.onVerificationVerified = { [weak self] in
            self?.onFinished?()
        }
        
        let verifyView = VerifyEmailView(viewModel: verifyViewModel)
        let hostingController = UIHostingController(rootView: verifyView)
        // Show navigation bar
        navigationController.setNavigationBarHidden(false, animated: true)
        navigationController.pushViewController(hostingController, animated: true)
    }

    private func showForgotPassword() {
        let viewModel = ForgotPasswordViewModel(authService: authService)
        
        viewModel.onBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        
        let view = ForgotPasswordView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: view)
        
        // Keep navigation bar hidden to maintain consistent UI style
        navigationController.setNavigationBarHidden(true, animated: true)
        navigationController.pushViewController(hostingController, animated: true)
    }
}
