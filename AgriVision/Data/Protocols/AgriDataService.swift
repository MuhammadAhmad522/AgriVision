import Foundation

protocol AgriDataService {
    func fetchSensorReadings() async throws -> [SensorReading]
}

struct SensorReading: Identifiable, Codable {
    let id: UUID
    let type: String
    let value: Double
    let unit: String
    let timestamp: Date
}
