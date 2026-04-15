import Foundation
import CoreLocation

/**
 The `Field` model represents a geographical area for farming.
 - `Identifiable`: Used for SwiftUI collections.
 - `Codable`: Used for network serialization.
 */
struct Field: Identifiable, Codable {
    let id: UUID
    let ownerId: UUID
    let name: String
    let areaHa: Double?
    let createdAt: Date
    
    // Context Logic
    let cropType: String?
    let plantationDate: Date?
    let expectedHarvestDate: Date?
    
    // Satellite Data
    let ndviScore: Double?
    let lastSatelliteSync: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case areaHa = "area_ha"
        case createdAt = "created_at"
        
        // Context mappings
        case cropType = "crop_type"
        case plantationDate = "plantation_date"
        case expectedHarvestDate = "expected_harvest_date"
        
        // Satellite mappings
        case ndviScore = "latest_ndvi"
        case lastSatelliteSync = "last_satellite_sync"
    }
}

/**
 A simple point representation for sending to the backend.
 Matches the Python `PointCoordinates` schema.
 */
struct PointCoordinates: Codable {
    let latitude: Double
    let longitude: Double
}

/**
 Represents a sensor to be created along with a field.
 Matches the backend's `SensorCreate` schema.
 */
struct SensorConfig: Codable {
    let deviceId: String
    let name: String?
    let sensorType: String
    
    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case name
        case sensorType = "sensor_type"
    }
}
