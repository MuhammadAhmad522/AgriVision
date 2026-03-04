// import Foundation
// import Combine

// /**
//  The `DashboardViewModel` connects the Data (Model) to the User Interface (View).
//  It uses the `ObservableObject` protocol, which means SwiftUI Views can "watch" it for changes.
//  Whenever a property marked with `@Published` changes, the UI will automatically update.
//  */
// class DashboardViewModel: ObservableObject {
    
//     // MARK: - Published Properties
    
//     /// The title of the screen. Because it's `@Published`, if we change this, the Navigation Title updates automatically.
//     @Published var title: String = "Dashboard"
    
//     /// The list of sensor readings. Our View will loop over this array to show data on the screen.
//     @Published var readings: [SensorReading] = []
    
//     /// A boolean flag to track if we are currently loading data. We use this to show a loading spinner.
//     @Published var isLoading: Bool = false
    
//     // MARK: - Private Properties
    
//     /// The service responsible for giving us data.
//     /// By keeping this private, we make sure the View can't accidentally mess with our data fetching logic.
//     private let dataService: AgriDataService
    
//     // MARK: - Initialization
    
//     /// This is called "Dependency Injection".
//     /// When we create the ViewModel, we *give* it the data service it needs.
//     /// It defaults to `MockAgriDataRepository`, but we could easily pass a real network service later.
//     init(dataService: AgriDataService = MockAgriDataRepository()) {
//         self.dataService = dataService
//     }
    
//     // MARK: - Methods
    
//     /// This method reaches out to the Data Service to get new readings.
//     /// `@MainActor` is very important here! It forces this method to run on the "Main Thread."
//     /// In iOS, any changes that affect the User Interface (like updating `readings` or `isLoading`)
//     /// MUST happen on the Main Thread, or the app will crash.
//     @MainActor
//     func refreshData() async {
//         // 1. Tell the UI we are loading. Because `isLoading` is @Published, the UI updates instantly.
//         isLoading = true
        
//         // `defer` ensures this block of code runs at the very end of the function,
//         // right before the function finishes, no matter what happens (success or error).
//         // This guarantees we always turn off the loading spinner.
//         defer { isLoading = false }
        
//         do {
//             // 2. Try to fetch the data. The `await` keyword means the app pauses here
//             // (without freezing the screen!) until the data comes back.
//             readings = try await dataService.fetchSensorReadings()
//         } catch {
//             // 3. If something goes wrong (like a network failure), we handle it here.
//             print("Error fetching data: \(error)")
//         }
//     }
// }
