import Foundation
import Combine

/// Manages the logic behind the scenes for the Login screen.
/// Data validation, tracking whether the app is loading, and communicating with Firebase
/// all happen here so the SwiftUI View can remain purely focused on UI design.
@MainActor
final class LoginViewModel: ObservableObject {

    // MARK: - Published State

    @Published var email: String = ""
    @Published var password: String = ""
    @Published var rememberMe: Bool = false
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    // MARK: - Dependencies
    
    private let authService: AuthService
    private var preferencesService: PreferencesService

    // MARK: - Coordinator Callbacks

    /// Injected by the Coordinator. Called when login succeeds so the Coordinator
    /// can navigate forward. The ViewModel has no knowledge of Coordinators (DIP).
    var onLoginSuccess: (() -> Void)?
    
    /// Called when login succeeds but email verification is required.
    var onRequireVerification: (() -> Void)?
    
    /// Called when the user taps "Forgot Password".
    var onForgotPassword: (() -> Void)?

    // MARK: - Initialization
    
    init(authService: AuthService, preferencesService: PreferencesService) {
        self.authService = authService
        self.preferencesService = preferencesService
        
        if let savedEmail = preferencesService.savedEmail {
            self.email = savedEmail
            self.rememberMe = true
        }
    }

    // MARK: - Actions

    func login() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try InputValidator.validate(email: email)
                if password.isEmpty { throw ValidationError.emptyField("Password") }
                
                try await authService.signIn(email: email, password: password)
                
                // Enforce email verification
                if !authService.isEmailVerified {
                    isLoading = false
                    onRequireVerification?()
                    return
                }
                
                if rememberMe {
                    preferencesService.savedEmail = email
                } else {
                    preferencesService.savedEmail = nil
                }
                
                isLoading = false
                onLoginSuccess?()
            } catch {
                isLoading = false
                errorMessage = error.userFacingMessage
                ToastMessageAutoDismiss.schedule(
                    expectedMessage: errorMessage ?? "",
                    currentMessage: { self.errorMessage },
                    clearMessage: { self.errorMessage = nil }
                )
            }
        }
    }

    func continueWithGoogle() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.signInWithGoogle()
                isLoading = false
                onLoginSuccess?()
            } catch {
                isLoading = false
                errorMessage = error.userFacingMessage
                ToastMessageAutoDismiss.schedule(
                    expectedMessage: errorMessage ?? "",
                    currentMessage: { self.errorMessage },
                    clearMessage: { self.errorMessage = nil }
                )
            }
        }
    }

    func forgotPassword() {
        onForgotPassword?()
    }
}
