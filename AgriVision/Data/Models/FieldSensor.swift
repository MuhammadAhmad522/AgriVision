import Foundation

struct FieldSensor: Decodable, Identifiable {
    let id: UUID
    let fieldId: UUID?
    let deviceId: String
    let name: String?
    let sensorType: String
    let batteryLevel: Double?
    let lastSeen: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case fieldId = "field_id"
        case deviceId = "device_id"
        case sensorType = "sensor_type"
        case batteryLevel = "battery_level"
        case lastSeen = "last_seen"
    }
}
