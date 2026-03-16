import Foundation
import Combine

@MainActor
final class ForgotPasswordViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let authService: AuthService
    
    var onBack: (() -> Void)?
    
    init(authService: AuthService) {
        self.authService = authService
    }
    
    func back() {
        onBack?()
    }
    
    func sendResetLink() {
        print("DEBUG: sendResetLink called with email: \(email)")
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                if email.isEmpty {
                     // explicit check just in case validator misses it or for faster feedback
                     throw ValidationError.emptyField("Email")
                }
                
                print("DEBUG: Validating email...")
                try InputValidator.validate(email: email)
                
                print("DEBUG: Checking sign-in methods...")
                let methods = try await authService.fetchSignInMethods(forEmail: email)
                
                // If the user only has Google Sign-In, prevent password reset
                if methods.contains("google.com") && !methods.contains("password") {
                    throw AuthError.unknown("You signed in with Google. Please use the 'Continue with Google' button to log in.")
                }
                
                print("DEBUG: Calling authService.resetPassword...")
                try await authService.resetPassword(email: email)
                
                print("DEBUG: Reset password success")
                isLoading = false
                successMessage = "Password reset link sent to \(email)."
            } catch {
                print("DEBUG: Reset password failed with error: \(error)")
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
}


