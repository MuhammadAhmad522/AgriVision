import Foundation
import Combine

/// Represents which form is currently active in the authentication container.
/// Defined in the ViewModel layer (not in a View file) because tab selection
/// is presentational state owned by the ViewModel, not UI markup (SRP).
enum AuthTab: String {
    case login = "Login"
    case signup = "Signup"
}

/// `AuthViewModel` owns the tab-switching state for the Auth container screen.
///
/// It exposes `onAuthComplete` so the Coordinator can react to a successful
/// login or signup without the View or any child ViewModel having direct
/// knowledge of the Coordinator (MVVM-C / DIP).
final class AuthViewModel: ObservableObject {

    // MARK: - Published State

    @Published var selectedTab: AuthTab = .login

    // MARK: - Coordinator Callback

    /// Injected by the Coordinator. Called when authentication completes so
    /// the Coordinator can navigate forward (MVVM-C — Views/VMs never navigate directly).
    var onAuthComplete: (() -> Void)?

    // MARK: - Actions

    func switchToLogin() {
        selectedTab = .login
    }

    func switchToSignup() {
        selectedTab = .signup
    }

    /// Propagates the auth-complete signal to the Coordinator.
    func authCompleted() {
        onAuthComplete?()
    }
}
