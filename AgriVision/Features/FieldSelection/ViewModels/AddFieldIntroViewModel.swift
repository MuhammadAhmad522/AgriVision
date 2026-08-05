import Foundation
import Combine

/// View Model for the AddFieldIntro Screen.
/// Manages the state and business logic for the introductory screen where users can add their first field.
@MainActor
final class AddFieldIntroViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var userName: String = "User"
    @Published var profileImageURL: URL?
    @Published var profileInitial: String = ""
    
    // MARK: - Dependencies
    private let authService: AuthService
    
    // MARK: - Coordinator Callbacks
    /// Callback to notify the coordinator to proceed to Add Field flow.
    var onAddFieldTapped: (() -> Void)?
    
    // MARK: - Initialization
    init(authService: AuthService) {
        self.authService = authService
        loadUserData()
    }
    
    private func loadUserData() {
        // Load Photo URL
        self.profileImageURL = authService.currentUserPhotoURL
        
        // Load Name
        if let name = authService.currentUserDisplayName, !name.isEmpty {
            let components = name.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ")
            
            // "Hi, [FirstName]" logic
            if let first = components.first, !first.isEmpty {
                self.userName = first
            } else {
                self.userName = name
            }
            
            // "Last Name Initial" logic
            // If we have a last name (more than 1 component), take the last one's first letter.
            // If only one name, take its first letter? User specifically said "last name first letter".
            // I'll prioritize last name, fallback to first name initial if only one name exists.
            if components.count > 1, let last = components.last, let firstChar = last.first {
                self.profileInitial = String(firstChar).uppercased()
            } else if let firstComponent = components.first, let firstChar = firstComponent.first {
                self.profileInitial = String(firstChar).uppercased()
            }
        } else {
            // Default if no name
            self.userName = "User"
            self.profileInitial = "U"
        }
    }
    
    // MARK: - Actions
    func addFieldAction() {
        onAddFieldTapped?()
    }
}
