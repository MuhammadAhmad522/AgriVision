import Foundation

class MockAgriDataRepository: AgriDataService {
    func fetchSensorReadings() async throws -> [SensorReading] {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
        
        return [
            SensorReading(id: UUID(), type: "Moisture", value: 45.5, unit: "%", timestamp: Date()),
            SensorReading(id: UUID(), type: "Temperature", value: 24.8, unit: "°C", timestamp: Date()),
            SensorReading(id: UUID(), type: "NPK", value: 120, unit: "ppm", timestamp: Date())
        ]
    }
}
