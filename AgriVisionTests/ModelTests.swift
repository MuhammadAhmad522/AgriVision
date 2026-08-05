import XCTest
import CoreLocation
@testable import AgriVision

final class FieldRecommendationTests: XCTestCase {

    func test_icon_irrigation() {
        let rec = FieldRecommendation(id: UUID(), fieldId: UUID(), category: "Irrigation", priority: "high", advice: "Water now", confidence: nil, status: "pending", ndviAtGeneration: nil, createdAt: Date())
        XCTAssertEqual(rec.icon, "\u{1F4A7}")
    }

    func test_icon_plantHealth() {
        let rec = FieldRecommendation(id: UUID(), fieldId: UUID(), category: "Plant Health", priority: "medium", advice: "Check leaves", confidence: nil, status: "pending", ndviAtGeneration: nil, createdAt: Date())
        XCTAssertEqual(rec.icon, "\u{1F33F}")
    }

    func test_icon_weatherAlert() {
        let rec = FieldRecommendation(id: UUID(), fieldId: UUID(), category: "Weather Alert", priority: "high", advice: "Storm coming", confidence: nil, status: "pending", ndviAtGeneration: nil, createdAt: Date())
        XCTAssertEqual(rec.icon, "\u{26C8}\u{FE0F}")
    }

    func test_icon_fertilizerWindow() {
        let rec = FieldRecommendation(id: UUID(), fieldId: UUID(), category: "Fertilizer Window", priority: "low", advice: "Apply now", confidence: nil, status: "pending", ndviAtGeneration: nil, createdAt: Date())
        XCTAssertEqual(rec.icon, "\u{1F331}")
    }

    func test_icon_harvestTiming() {
        let rec = FieldRecommendation(id: UUID(), fieldId: UUID(), category: "Harvest Timing", priority: "high", advice: "Harvest soon", confidence: nil, status: "pending", ndviAtGeneration: nil, createdAt: Date())
        XCTAssertEqual(rec.icon, "\u{1F33E}")
    }

    func test_icon_pestRisk() {
        let rec = FieldRecommendation(id: UUID(), fieldId: UUID(), category: "Pest Risk", priority: "high", advice: "Check for pests", confidence: nil, status: "pending", ndviAtGeneration: nil, createdAt: Date())
        XCTAssertEqual(rec.icon, "\u{1F41B}")
    }

    func test_icon_default() {
        let rec = FieldRecommendation(id: UUID(), fieldId: UUID(), category: "Unknown Category", priority: "low", advice: "Monitor", confidence: nil, status: "pending", ndviAtGeneration: nil, createdAt: Date())
        XCTAssertEqual(rec.icon, "\u{1F52C}")
    }

    func test_priorityColor_high() {
        let rec = FieldRecommendation(id: UUID(), fieldId: UUID(), category: "Irrigation", priority: "high", advice: "", confidence: nil, status: "pending", ndviAtGeneration: nil, createdAt: Date())
        XCTAssertEqual(rec.priorityColor, "red")
    }

    func test_priorityColor_medium() {
        let rec = FieldRecommendation(id: UUID(), fieldId: UUID(), category: "Irrigation", priority: "medium", advice: "", confidence: nil, status: "pending", ndviAtGeneration: nil, createdAt: Date())
        XCTAssertEqual(rec.priorityColor, "orange")
    }

    func test_priorityColor_low() {
        let rec = FieldRecommendation(id: UUID(), fieldId: UUID(), category: "Irrigation", priority: "low", advice: "", confidence: nil, status: "pending", ndviAtGeneration: nil, createdAt: Date())
        XCTAssertEqual(rec.priorityColor, "teal")
    }

    func test_confidencePercent_withValue() {
        let rec = FieldRecommendation(id: UUID(), fieldId: UUID(), category: "Irrigation", priority: "high", advice: "", confidence: 0.85, status: "pending", ndviAtGeneration: nil, createdAt: Date())
        XCTAssertEqual(rec.confidencePercent, "85%")
    }

    func test_confidencePercent_nil() {
        let rec = FieldRecommendation(id: UUID(), fieldId: UUID(), category: "Irrigation", priority: "high", advice: "", confidence: nil, status: "pending", ndviAtGeneration: nil, createdAt: Date())
        XCTAssertEqual(rec.confidencePercent, "N/A")
    }

    func test_coalescingDefaultValues() {
        let rec = FieldRecommendation(id: UUID(), fieldId: UUID(), category: "Test", priority: "low", advice: "Test", confidence: nil, status: "pending", ndviAtGeneration: nil, createdAt: Date())
        XCTAssertEqual(rec.safetyLevel, "guarded")
        XCTAssertFalse(rec.requiresExpertConfirmation)
        XCTAssertNil(rec.rationale)
        XCTAssertNil(rec.confidenceReason)
    }
}

final class SensorReadingTests: XCTestCase {

    func test_synthesizedID() {
        let now = Date()
        let reading = SensorReading(sensor_id: UUID(), time: now, temperature: nil, moisture: nil, humidity: nil)
        let expected = "\(reading.sensor_id.uuidString)-\(now.timeIntervalSince1970)"
        XCTAssertEqual(reading.id, expected)
    }

    func test_defaultValues() {
        let reading = SensorReading(sensor_id: UUID(), time: Date(), temperature: 25.0, moisture: 60.0, humidity: 70.0)
        XCTAssertNil(reading.ph)
        XCTAssertNil(reading.ec)
        XCTAssertNil(reading.npk_n)
        XCTAssertNil(reading.npk_p)
        XCTAssertNil(reading.npk_k)
    }
}

final class PointCoordinatesTests: XCTestCase {

    func test_coordinateConversion() {
        let point = PointCoordinates(latitude: 31.5, longitude: 74.3)
        let coord = point.coordinate
        XCTAssertEqual(coord.latitude, 31.5)
        XCTAssertEqual(coord.longitude, 74.3)
    }
}

final class FieldReplacingCoordinatesTests: XCTestCase {

    func test_replacingCoordinates() {
        let fieldId = UUID()
        let originalCoords = [PointCoordinates(latitude: 31.5, longitude: 74.3)]
        let field = Field(
            id: fieldId, ownerId: UUID(), name: "Test",
            coordinates: originalCoords, areaHa: 10, createdAt: Date(),
            cropType: nil, plantationDate: nil, expectedHarvestDate: nil,
            status: "active",
            ndviScore: 0.5, lastSatelliteSync: Date()
        )
        let newCoords = [PointCoordinates(latitude: 31.6, longitude: 74.4)]
        let replaced = field.replacingCoordinates(with: newCoords)
        XCTAssertEqual(replaced.coordinates?.first?.latitude, 31.6)
        XCTAssertEqual(replaced.id, fieldId)
        XCTAssertEqual(replaced.name, "Test")
        XCTAssertEqual(replaced.status, "active")
    }

    func test_replacingCoordinates_preservesOtherFields() {
        let field = Field(
            id: UUID(), ownerId: UUID(), name: "Test",
            coordinates: nil, areaHa: 10, createdAt: Date(),
            cropType: "Wheat", plantationDate: Date(), expectedHarvestDate: Date(),
            ndviScore: 0.5, lastSatelliteSync: Date()
        )
        let replaced = field.replacingCoordinates(with: [])
        XCTAssertEqual(replaced.cropType, "Wheat")
        XCTAssertEqual(replaced.areaHa, 10)
        XCTAssertEqual(replaced.agroStatus, "pending")
        XCTAssertTrue(replaced.agroRetryable)
    }
}

final class SensorConfigTests: XCTestCase {

    func test_sensorConfigCodingKeys() {
        let json = """
        {"device_id": "ESP32_001", "name": "Sensor 1", "sensor_type": "multi_sensor"}
        """
        let data = json.data(using: .utf8)!
        let config = try! JSONDecoder().decode(SensorConfig.self, from: data)
        XCTAssertEqual(config.deviceId, "ESP32_001")
        XCTAssertEqual(config.name, "Sensor 1")
        XCTAssertEqual(config.sensorType, "multi_sensor")
    }
}

final class FieldDecodingTests: XCTestCase {

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = APIDateCoding.fractional.date(from: value) ?? APIDateCoding.standard.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date")
        }
        return decoder
    }

    func test_fieldDecoding_full() throws {
        let json = """
        {
            "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "owner_id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "name": "Test Field",
            "area_ha": 10.5,
            "created_at": "2024-01-01T00:00:00Z",
            "crop_type": "Wheat",
            "status": "active",
            "agro_status": "available",
            "agro_retryable": true,
            "latest_ndvi": 0.75,
            "last_satellite_sync": "2024-01-01T00:00:00Z"
        }
        """
        let data = json.data(using: .utf8)!
        let field = try decoder().decode(Field.self, from: data)
        XCTAssertEqual(field.name, "Test Field")
        XCTAssertEqual(field.areaHa, 10.5)
        XCTAssertEqual(field.cropType, "Wheat")
        XCTAssertEqual(field.status, "active")
        XCTAssertEqual(field.agroStatus, "available")
        XCTAssertEqual(field.ndviScore, 0.75)
    }

    func test_fieldDecoding_minimal() throws {
        let json = """
        {
            "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "owner_id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "name": "Minimal",
            "area_ha": 5.0,
            "created_at": "2024-06-15T12:00:00Z",
            "status": "active",
            "agro_status": "pending",
            "agro_retryable": false
        }
        """
        let data = json.data(using: .utf8)!
        let field = try decoder().decode(Field.self, from: data)
        XCTAssertEqual(field.name, "Minimal")
        XCTAssertEqual(field.areaHa, 5.0)
        XCTAssertNil(field.cropType)
        XCTAssertEqual(field.agroStatus, "pending")
        XCTAssertFalse(field.agroRetryable)
    }
}

final class BackendAPIErrorTests: XCTestCase {

    func test_errorDecoding() throws {
        let json = """
        {
            "error": {
                "code": "field_not_found",
                "message": "Field not found.",
                "details": [],
                "retryable": false,
                "request_id": "req-abc-123"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let envelope = try JSONDecoder().decode(ErrorEnvelope.self, from: data)
        XCTAssertEqual(envelope.error.code, "field_not_found")
        XCTAssertEqual(envelope.error.message, "Field not found.")
        XCTAssertFalse(envelope.error.retryable)
        XCTAssertEqual(envelope.error.requestId, "req-abc-123")
    }
}

final class DataSourceStatusTests: XCTestCase {

    func test_availability() {
        let state = SourceState<Int>(status: "available", lastUpdated: nil, data: nil, message: nil)
        XCTAssertEqual(state.availability, .available)
    }

    func test_availability_pending() {
        let state = SourceState<Int>(status: "pending", lastUpdated: nil, data: nil, message: nil)
        XCTAssertEqual(state.availability, .pending)
    }

    func test_availability_notConfigured() {
        let state = SourceState<Int>(status: "not_configured", lastUpdated: nil, data: nil, message: nil)
        XCTAssertEqual(state.availability, .notConfigured)
    }

    func test_canRetry() {
        let state = SourceState<Int>(status: "stale", lastUpdated: nil, data: nil, message: nil, retryable: true)
        XCTAssertTrue(state.canRetry)
    }

    func test_retryableNil() {
        let state = SourceState<Int>(status: "available", lastUpdated: nil, data: nil, message: nil)
        XCTAssertFalse(state.canRetry)
    }
}
