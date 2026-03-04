import Foundation

/**
 A `struct` holding the data for a single sensor reading.
 - `Identifiable`: Allows us to easily list these items in a SwiftUI `List` or `ForEach`.
 - `Codable`: Allows us to easily convert this data to and from JSON (which we get from a server).
 */
struct SensorReading: Identifiable, Codable {
    let id: UUID
    let type: String
    let value: Double
    let unit: String
    let timestamp: Date
}
