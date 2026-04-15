import Foundation

/**
 A `struct` holding the data for a single sensor reading.
 - `Identifiable`: Allows us to easily list these items in a SwiftUI `List` or `ForEach`.
 - `Codable`: Allows us to easily convert this data to and from JSON (which we get from a server).
 */
struct SensorReading: Identifiable, Codable {
    let sensor_id: UUID
    let time: Date
    let temperature: Double?
    let moisture: Double?
    let humidity: Double?
    
    // Synthesize an ID for SwiftUI lists since timeseries rows don't have UUID primary keys themselves
    var id: String {
        "\(sensor_id.uuidString)-\(time.timeIntervalSince1970)"
    }
}
