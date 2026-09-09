import Foundation
import CoreLocation

/**
 The `Field` model represents a geographical area for farming.
 - `Identifiable`: Used for SwiftUI collections.
 - `Codable`: Used for network serialization.
 */
struct Field: Identifiable, Codable, Equatable {
    let id: UUID
    let ownerId: UUID
    let name: String
    /// Ordered vertices of the boundary drawn during field selection.
    let coordinates: [PointCoordinates]?
    let areaHa: Double?
    let createdAt: Date
    
    // Context Logic
    let cropType: String?
    let plantationDate: Date?
    let expectedHarvestDate: Date?

    var status: String = "active"
    var archivedAt: Date? = nil
    var updatedAt: Date? = nil
    var agromonitoringPolygonId: String? = nil
    var agroStatus: String? = nil
    var agroError: String? = nil
    var agroRetryable: Bool? = nil
    
    // Satellite Data
    let ndviScore: Double?
    let lastSatelliteSync: Date?

    // AI-computed holistic field health — distinct from ndviScore (a raw vegetation index)
    var latestHealthScore: Double? = nil
    var latestHealthLabel: String? = nil
    var latestHealthRationale: String? = nil
    var latestHealthUpdatedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case coordinates
        case areaHa = "area_ha"
        case createdAt = "created_at"
        
        // Context mappings
        case cropType = "crop_type"
        case plantationDate = "plantation_date"
        case expectedHarvestDate = "expected_harvest_date"
        case status
        case archivedAt = "archived_at"
        case updatedAt = "updated_at"
        case agromonitoringPolygonId = "agromonitoring_polygon_id"
        case agroStatus = "agro_status"
        case agroError = "agro_error"
        case agroRetryable = "agro_retryable"
        
        // Satellite mappings
        case ndviScore = "latest_ndvi"
        case lastSatelliteSync = "last_satellite_sync"

        // AI-computed field health mappings
        case latestHealthScore = "latest_health_score"
        case latestHealthLabel = "latest_health_label"
        case latestHealthRationale = "latest_health_rationale"
        case latestHealthUpdatedAt = "latest_health_updated_at"
    }

    /// Returns the same field with a locally retained boundary.
    ///
    /// This is used when an older backend response omits its geometry even though the
    /// vertices were successfully submitted during field creation.
    func replacingCoordinates(with coordinates: [PointCoordinates]) -> Field {
        var copy = Field(
            id: id,
            ownerId: ownerId,
            name: name,
            coordinates: coordinates,
            areaHa: areaHa,
            createdAt: createdAt,
            cropType: cropType,
            plantationDate: plantationDate,
            expectedHarvestDate: expectedHarvestDate,
            ndviScore: ndviScore,
            lastSatelliteSync: lastSatelliteSync
        )
        copy.status = status
        copy.archivedAt = archivedAt
        copy.updatedAt = updatedAt
        copy.agromonitoringPolygonId = agromonitoringPolygonId
        copy.agroStatus = agroStatus
        copy.agroError = agroError
        copy.agroRetryable = agroRetryable
        copy.latestHealthScore = latestHealthScore
        copy.latestHealthLabel = latestHealthLabel
        copy.latestHealthRationale = latestHealthRationale
        copy.latestHealthUpdatedAt = latestHealthUpdatedAt
        return copy
    }
}

/**
 A simple point representation for sending to the backend.
 Matches the Python `PointCoordinates` schema.
 */
struct PointCoordinates: Codable, Equatable {
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
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
