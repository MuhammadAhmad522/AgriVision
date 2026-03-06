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

    /// The list of sensor readings displayed by the View.
    @Published var readings: [SensorReading] = []

    /// A boolean flag indicating an in-flight data request. Used to show a loading spinner.
    @Published var isLoading: Bool = false

    /// A human-readable error message set when data fetching fails, `nil` otherwise.
    /// The View observes this to surface error banners or alerts without containing
    /// any error-handling logic itself (Single Responsibility Principle).
    @Published var errorMessage: String?

    // MARK: - Private Properties

    /// The service responsible for supplying data.
    /// Kept as a protocol (`AgriDataService`) so the ViewModel never depends on a
    /// concrete repository — satisfying the Dependency Inversion Principle.
    private let dataService: AgriDataService

    // MARK: - Initialization

    /// Initializer-based dependency injection: the caller supplies the concrete data service.
    /// No default value is provided here so that the composition root (Coordinator) is always
    /// the single place where concrete types are chosen (Dependency Inversion Principle).
    init(dataService: AgriDataService) {
        self.dataService = dataService
    }

    // MARK: - Methods

    /// Fetches new sensor readings from the data service.
    /// `@MainActor` ensures all `@Published` mutations happen on the main thread.
    @MainActor
    func refreshData() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            readings = try await dataService.fetchSensorReadings()
        } catch {
            // Surface the error to the View via the published `errorMessage` property
            // rather than silently printing it. The View decides how to present it.
            errorMessage = error.localizedDescription
        }
    }
}
