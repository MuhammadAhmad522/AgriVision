import Foundation
import Combine

/// Connects the SettingsView to the backend services.
/// It handles user session actions such as signing out or linking multiple authentication providers together.
final class SettingsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var title: String = "Settings"

    // MARK: - Dependencies

    private let authService: AuthService

    // MARK: - Coordinator Callbacks

    /// Called when the user successfully signs out, telling the Coordinator to navigate away.
    var onSignOut: (() -> Void)?

    // MARK: - Initialization

    init(authService: AuthService) {
        self.authService = authService
    }

    // MARK: - Actions

    /// Signs the user out of the app.
    func signOut() {
        do {
            try authService.signOut()
            onSignOut?()
        } catch {
            errorMessage = "Failed to sign out: \(error.userFacingMessage)"
        }
    }

    /// Links an existing email/password account with a Google account so the user can log in with either.
    func linkGoogleAccount() {
        Task {
            await MainActor.run { isLoading = true }

            do {
                try await authService.linkGoogleAccount()
                await MainActor.run {
                    isLoading = false
                    successMessage = "Account successfully linked with Google!"
                }
                
                // Clear the success message after 3 seconds
                try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                await MainActor.run {
                    if successMessage == "Account successfully linked with Google!" {
                        successMessage = nil
                    }
                }
            } catch {
                let errorMsg = "Failed to link account: \(error.userFacingMessage)"
                await MainActor.run {
                    isLoading = false
                    errorMessage = errorMsg
                }
                
                // Clear the error message after 3 seconds
                try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                await MainActor.run {
                    if errorMessage == errorMsg {
                        errorMessage = nil
                    }
                }
            }
        }
    }
}
