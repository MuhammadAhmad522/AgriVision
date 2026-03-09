import Foundation
import Combine

/// Owns the form state and actions for the Login screen.
///
/// Moving form fields out of the View and into the ViewModel satisfies SRP:
/// the View becomes a passive renderer and this class is independently unit-testable
/// with no UI dependencies (MVVM-C ViewModel requirements).
final class LoginViewModel: ObservableObject {

    // MARK: - Published State

    @Published var email: String = ""
    @Published var password: String = ""
    @Published var rememberMe: Bool = false

    // MARK: - Coordinator Callbacks

    /// Injected by the Coordinator. Called when login succeeds so the Coordinator
    /// can navigate forward. The ViewModel has no knowledge of Coordinators (DIP).
    var onLoginSuccess: (() -> Void)?

    // MARK: - Actions

    func login() {
        // TODO: call an injected AuthService once it exists.
        onLoginSuccess?()
    }

    func forgotPassword() {
        // TODO: ask the Coordinator to present a Forgot-Password sub-flow.
    }
}
