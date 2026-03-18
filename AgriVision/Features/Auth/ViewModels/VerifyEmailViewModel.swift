import Foundation
import Combine

@MainActor
final class VerifyEmailViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var message: String?
    @Published var isVerified: Bool = false
    
    private let authService: AuthService
    var onVerificationVerified: (() -> Void)?
    
    init(authService: AuthService) {
        self.authService = authService
    }
    
    func checkVerificationStatus() {
        isLoading = true
        message = nil
        
        Task {
            do {
                try await authService.reloadUser()
                if authService.isEmailVerified {
                    self.isVerified = true
                    self.message = "Email verified successfully!"
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1s delay
                    onVerificationVerified?()
                } else {
                    self.message = "Email is not verified yet. Please check your inbox."
                }
                self.isLoading = false
            } catch {
                self.message = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func resendVerificationEmail() {
        isLoading = true
        message = nil
        
        Task {
            do {
                try await authService.sendEmailVerification()
                self.message = "Verification email sent!"
                self.isLoading = false
            } catch {
                self.message = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
