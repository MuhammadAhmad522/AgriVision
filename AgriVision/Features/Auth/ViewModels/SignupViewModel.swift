import Foundation
import Combine

/// Owns the form state and actions for the Signup screen.
///
/// Moving form fields out of the View and into the ViewModel satisfies SRP:
/// the View becomes a passive renderer and this class is independently unit-testable
/// with no UI dependencies (MVVM-C ViewModel requirements).
@MainActor
final class SignupViewModel: ObservableObject {

    enum Field {
        case firstName, lastName, email, password, confirmPassword
    }

    // MARK: - Published State

    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    
    // MARK: - Validation Errors (Real-time)
    @Published var firstNameError: String?
    @Published var lastNameError: String?
    @Published var emailError: String?
    @Published var passwordError: String?
    @Published var confirmPasswordError: String?
    
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    // MARK: - Dependencies
    
    private let authService: AuthService
    private let userProfileService: UserProfileService
    
    // MARK: - Integration

    init(authService: AuthService, userProfileService: UserProfileService) {
        self.authService = authService
        self.userProfileService = userProfileService
    }

    // MARK: - Coordinator Callback

    /// Called when signup succeeds and email verification is needed.
    var onRequireVerification: (() -> Void)?

    // MARK: - Actions
    
    func validateField(_ field: Field, value: String) {
        switch field {
        case .firstName:
            firstNameError = nil
            do { try InputValidator.validate(value: value, fieldName: "First Name") }
            catch { firstNameError = error.userFacingMessage }
            
        case .lastName:
            lastNameError = nil
            do { try InputValidator.validate(value: value, fieldName: "Last Name") }
            catch { lastNameError = error.userFacingMessage }
            
        case .email:
            emailError = nil
            do { try InputValidator.validate(email: value) }
            catch { emailError = error.userFacingMessage }
            
        case .password:
            passwordError = nil
            do { try InputValidator.validate(password: value, minLength: 8) }
            catch { passwordError = error.userFacingMessage }
            
        case .confirmPassword:
            confirmPasswordError = nil
            if value != password {
                confirmPasswordError = ValidationError.passwordsDoNotMatch.localizedDescription
            }
        }
    }

    func register() {
        isLoading = true
        errorMessage = nil
        
        // Final Validation check
        validateField(.firstName, value: firstName)
        validateField(.lastName, value: lastName)
        validateField(.email, value: email)
        validateField(.password, value: password)
        validateField(.confirmPassword, value: confirmPassword)
        
        guard firstNameError == nil, lastNameError == nil, emailError == nil, passwordError == nil, confirmPasswordError == nil else {
            isLoading = false
            return
        }
        
        Task {
            do {
                let fullName = "\(firstName) \(lastName)"
                // Create User credentials
                try await authService.signUp(email: email, password: password)
                
                // Update profile separately from credential creation (SRP)
                try await userProfileService.updateDisplayName(fullName)
                
                // Send Verification Email
                try await authService.sendEmailVerification()
                
                isLoading = false
                onRequireVerification?()
            } catch {
                isLoading = false
                // Map generic errors or show specific backend errors
                errorMessage = error.userFacingMessage
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
                onSignupAutoLogin?()
            } catch {
                isLoading = false
                errorMessage = error.userFacingMessage
            }
        }
    }
    
    // Callback for direct login (e.g. Google)
    var onSignupAutoLogin: (() -> Void)?
}
