import Foundation
import Combine

class DashboardViewModel: ObservableObject {
    @Published var title: String = "Dashboard"
    @Published var readings: [SensorReading] = []
    @Published var isLoading: Bool = false
    
    private let dataService: AgriDataService
    
    init(dataService: AgriDataService = MockAgriDataRepository()) {
        self.dataService = dataService
    }
    
    @MainActor
    func refreshData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            readings = try await dataService.fetchSensorReadings()
        } catch {
            print("Error fetching data: \(error)")
        }
    }
}
