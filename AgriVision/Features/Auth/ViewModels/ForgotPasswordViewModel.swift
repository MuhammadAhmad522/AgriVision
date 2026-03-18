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
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                try InputValidator.validate(email: email)
                try await authService.resetPassword(email: email)
                isLoading = false
                successMessage = "Password reset link sent to \(email)."
            } catch {
                isLoading = false
                errorMessage = error.userFacingMessage
            }
        }
    }
}
