import Foundation

/**
 A \`protocol\` in Swift is like a contract or a blueprint.
 It says: "Any class or struct that uses this protocol MUST have these specific methods."
 We use this so our ViewModels don't care *where* the data comes from (mock data or a real server),
 as long as it has a \`fetchSensorReadings\` method.
 */
protocol AgriDataService {
    /// Fetches sensor readings. It is marked \`async\` because it might take time (like downloading from the internet),
    /// and \`throws\` because it might fail (like if the internet is disconnected).
    func fetchSensorReadings() async throws -> [SensorReading]
}

/**
 A \`struct\` holding the data for a single sensor reading.
 - \`Identifiable\`: Allows us to easily list these items in a SwiftUI \`List\` or \`ForEach\`.
 - \`Codable\`: Allows us to easily convert this data to and from JSON (which we get from a server).
 */
struct SensorReading: Identifiable, Codable {
    let id: UUID
    let type: String
    let value: Double
    let unit: String
    let timestamp: Date
}
