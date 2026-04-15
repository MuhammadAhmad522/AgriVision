import Foundation
import Combine

/**
 The `DashboardViewModel` connects the Data (Model) to the User Interface (View).
 It uses the `ObservableObject` protocol, which means SwiftUI Views can "watch" it for changes.
 Whenever a property marked with `@Published` changes, the UI will automatically update.
 */
final class DashboardViewModel: ObservableObject {

    // MARK: - Published Properties

    /// The title of the screen.
    @Published var title: String = "Dashboard"
    
    /// Success message for toast/banner
    @Published var successMessage: String?

    /// The list of sensor readings displayed by the View.
    @Published var readings: [SensorReading] = []

    /// The list of user's fields, containing satellite data.
    @Published var fields: [Field] = []
    
    /// AI-generated agronomic recommendations for the primary field.
    @Published var recommendations: [FieldRecommendation] = []

    /// A boolean flag indicating an in-flight data request. Used to show a loading spinner.
    @Published var isLoading: Bool = false

    /// A human-readable error message set when data fetching fails, `nil` otherwise.
    /// The View observes this to surface error banners or alerts without containing
    /// any error-handling logic itself (Single Responsibility Principle).
    @Published var errorMessage: String?

    /// The display name of the currently signed-in user.
    @Published var userName: String?

    // MARK: - Private Properties

    /// The service responsible for supplying data.
    /// Kept as a protocol (`AgriDataService`) so the ViewModel never depends on a
    /// concrete repository — satisfying the Dependency Inversion Principle.
    private let dataService: AgriDataService
    
    /// The authentication service for managing user sessions.
    private let authService: AuthService
    
    // MARK: - Coordinator Callbacks
    
    /// Injected by the Coordinator. Called when the user signs out.
    var onSignOut: (() -> Void)?
    
    /// Injected by the Coordinator. Called when the user taps the settings button.
    var onSettingsTap: (() -> Void)?
    
    /// Injected by the Coordinator. Called when the user taps the AI Chat button.
    var onChatTapped: ((UUID) -> Void)?

    // MARK: - Initialization

    /// Initializer-based dependency injection: the caller supplies the concrete data service.
    /// No default value is provided here so that the composition root (Coordinator) is always
    /// the single place where concrete types are chosen (Dependency Inversion Principle).
    init(dataService: AgriDataService, authService: AuthService) {
        self.dataService = dataService
        self.authService = authService
        self.userName = authService.currentUserDisplayName
    }

    // MARK: - Methods
    
    /// Signs out the current user and notifies the coordinator.
    func signOut() {
        do {
            try authService.signOut()
            onSignOut?()
        } catch {
            errorMessage = "Failed to sign out: \(error.userFacingMessage)"
        }
    }
    
    /// Helper to trigger the settings navigation flow.
    func openSettings() {
        onSettingsTap?()
    }
    
    /// Triggers the AI Chat for the primary field.
    func openChat() {
        guard let primaryField = fields.first else { return }
        onChatTapped?(primaryField.id)
    }
    
    /// Links the current user's account with Google credentials.
    /// This allows users who signed up with email/password to also sign in with Google.
    func linkGoogle() {
        Task {
            // Ensure UI updates happen on main thread
            await MainActor.run { isLoading = true }
            
            do {
                try await authService.linkGoogleAccount()
                await MainActor.run {
                    isLoading = false
                    successMessage = "Account successfully linked with Google!"
                }
                // Clear after delay
                try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                await MainActor.run {
                    // Only clear if the message hasn't changed
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
                // Clear after delay
                try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                await MainActor.run {
                    if errorMessage == errorMsg {
                        errorMessage = nil
                    }
                }
            }
        }
    }

    /// Fetches new sensor readings from the data service.
    /// `@MainActor` ensures all `@Published` mutations happen on the main thread.
    @MainActor
    func refreshData() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let fetchedReadings = try await dataService.fetchSensorReadings()
            let fetchedFields = try await dataService.fetchFields()
            
            readings = fetchedReadings
            fields = fetchedFields
            
            // Fetch AI recommendations for the primary field
            if let primaryField = fetchedFields.first {
                let fetchedRecs = try await dataService.fetchRecommendations(for: primaryField.id)
                recommendations = fetchedRecs
            }
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    // MARK: - Computed Properties for UI
    
    /// Returns the health summary for the primary field.
    var healthSummary: (score: Double, message: String, color: String)? {
        guard let field = fields.first, let ndvi = field.ndviScore else { return nil }
        
        let message: String
        let color: String
        
        switch ndvi {
        case 0.7...1.0:
            message = "Excellent Crop Health"
            color = "green"
        case 0.4..<0.7:
            message = "Good Health - Monitor Moisture"
            color = "orange"
        case 0..<0.4:
            message = "Low Vitality - Inspection Required"
            color = "red"
        default:
            message = "Awaiting Analysis"
            color = "gray"
        }
        
        return (ndvi, message, color)
    }
}
