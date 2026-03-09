import Foundation
import Combine

/// Owns the form state and actions for the Signup screen.
///
/// Moving form fields out of the View and into the ViewModel satisfies SRP:
/// the View becomes a passive renderer and this class is independently unit-testable
/// with no UI dependencies (MVVM-C ViewModel requirements).
final class SignupViewModel: ObservableObject {

    // MARK: - Published State

    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""

    // MARK: - Coordinator Callback

    /// Injected by the Coordinator. Called when signup succeeds so the Coordinator
    /// can navigate forward. The ViewModel has no knowledge of Coordinators (DIP).
    var onSignupSuccess: (() -> Void)?

    // MARK: - Actions

    func register() {
        // TODO: call an injected AuthService once it exists.
        onSignupSuccess?()
    }
}
