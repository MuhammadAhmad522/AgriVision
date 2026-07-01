import Foundation
import Combine

/// Connects the SettingsView to the backend services.
/// It handles user session actions such as signing out or linking multiple authentication providers together.
final class SettingsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var fields: [Field] = []
    @Published var activeFieldId: UUID?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var title: String = "Settings"

    // MARK: - Dependencies

    private let authService: AuthService
    private let dataService: AgriDataService
    private var preferencesService: PreferencesService

    // MARK: - Coordinator Callbacks

    /// Called when the user successfully signs out, telling the Coordinator to navigate away.
    var onSignOut: (() -> Void)?
    
    /// Called when a field is deleted and the list becomes empty.
    var onFieldsEmptied: (() -> Void)?
    
    /// Called when the user switches the active field.
    var onActiveFieldChanged: (() -> Void)?

    // MARK: - Initialization

    init(
        authService: AuthService, 
        dataService: AgriDataService, 
        preferencesService: PreferencesService
    ) {
        self.authService = authService
        self.dataService = dataService
        self.preferencesService = preferencesService
        self.activeFieldId = preferencesService.activeFieldId
        
        refreshFields()
    }
    
    // MARK: - Field Management
    
    @MainActor
    func refreshFields() {
        Task {
            do {
                self.fields = try await dataService.fetchFields()
                
                // If there's no active field but fields exist, pick the first one
                if activeFieldId == nil, let firstField = fields.first {
                    selectField(firstField.id)
                }
            } catch {
                errorMessage = "Failed to load fields: \(error.userFacingMessage)"
                ToastMessageAutoDismiss.schedule(
                    expectedMessage: errorMessage ?? "",
                    currentMessage: { self.errorMessage },
                    clearMessage: { self.errorMessage = nil }
                )
            }
        }
    }
    
    func selectField(_ id: UUID) {
        activeFieldId = id
        preferencesService.activeFieldId = id
        onActiveFieldChanged?()
    }
    
    @MainActor
    func deleteField(_ id: UUID) {
        isLoading = true
        Task {
            do {
                try await dataService.deleteField(id: id)
                
                // Update local list
                fields.removeAll { $0.id == id }
                
                // Handle deletion of the active field
                if activeFieldId == id {
                    if let nextField = fields.first {
                        selectField(nextField.id)
                    } else {
                        activeFieldId = nil
                        preferencesService.activeFieldId = nil
                        onFieldsEmptied?()
                    }
                } else if fields.isEmpty {
                    onFieldsEmptied?()
                }
                
                isLoading = false
                successMessage = "Field deleted successfully."
            } catch {
                isLoading = false
                errorMessage = "Failed to delete field: \(error.userFacingMessage)"
                ToastMessageAutoDismiss.schedule(
                    expectedMessage: errorMessage ?? "",
                    currentMessage: { self.errorMessage },
                    clearMessage: { self.errorMessage = nil }
                )
            }
        }
    }

    // MARK: - Actions

    /// Signs the user out of the app.
    func signOut() {
        do {
            try authService.signOut()
            onSignOut?()
        } catch {
            errorMessage = "Failed to sign out: \(error.userFacingMessage)"
            ToastMessageAutoDismiss.schedule(
                expectedMessage: errorMessage ?? "",
                currentMessage: { self.errorMessage },
                clearMessage: { self.errorMessage = nil }
            )
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
                ToastMessageAutoDismiss.schedule(
                    expectedMessage: "Account successfully linked with Google!",
                    currentMessage: { self.successMessage },
                    clearMessage: { self.successMessage = nil }
                )
                
                // Clear the success message after 3 seconds
            } catch {
                let errorMsg = "Failed to link account: \(error.userFacingMessage)"
                await MainActor.run {
                    isLoading = false
                    errorMessage = errorMsg
                }
                ToastMessageAutoDismiss.schedule(
                    expectedMessage: errorMsg,
                    currentMessage: { self.errorMessage },
                    clearMessage: { self.errorMessage = nil }
                )
            }
        }
    }
}
