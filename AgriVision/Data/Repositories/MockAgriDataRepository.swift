import Foundation

/**
 This class provides "fake" or "mock" data for our app while we are still developing it,
 or if we don't have a real server setup yet.
 It conforms to the \`AgriDataService\` protocol, meaning it promises to provide a \`fetchSensorReadings()\` method.
 */
class MockAgriDataRepository: AgriDataService {
    
    /// This method creates fake sensor data and returns it.
    func fetchSensorReadings() async throws -> [SensorReading] {
        // Simulate a network delay of 1 second (1,000,000,000 nanoseconds)
        // This is to make it feel like we are actually waiting for a server to respond.
        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
        
        // Return an array of fake sensor readings
        return [
            SensorReading(id: UUID(), type: "Moisture", value: 45.5, unit: "%", timestamp: Date()),
            SensorReading(id: UUID(), type: "Temperature", value: 24.8, unit: "°C", timestamp: Date()),
            SensorReading(id: UUID(), type: "NPK", value: 120, unit: "ppm", timestamp: Date())
        ]
    }
}
