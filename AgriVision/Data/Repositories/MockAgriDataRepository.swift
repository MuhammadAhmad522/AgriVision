import Foundation
import CoreLocation

/**
 This class provides "fake" or "mock" data for our app while we are still developing it,
 or if we don't have a real server setup yet.
 It conforms to the `AgriDataService` protocol, meaning it promises to provide a `fetchSensorReadings()` method.
 */
class MockAgriDataRepository: AgriDataService {
    
    private let mockCropType: String
    
    init(mockCropType: String = "Wheat") {
        self.mockCropType = mockCropType
    }
    
    /// This method creates fake sensor data and returns it.
    /// Fakes a field save operation
    func saveField(
        name: String,
        coordinates: [CLLocationCoordinate2D],
        areaHa: Double?,
        cropType: String?,
        plantationDate: Date?,
        expectedHarvestDate: Date?,
        sensors: [SensorConfig]?
    ) async throws -> Field {
        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
        return Field(
            id: UUID(),
            ownerId: UUID(),
            name: name,
            areaHa: areaHa,
            createdAt: Date(),
            cropType: cropType,
            plantationDate: plantationDate,
            expectedHarvestDate: expectedHarvestDate,
            ndviScore: 0.85, // Mock a healthy field
            lastSatelliteSync: Date()
        )
    }

    /// Mock implementation for fetching fields.
    func fetchFields() async throws -> [Field] {
        // Return a mock field to populate the dashboard UI
        return [
            Field(
                id: UUID(),
                ownerId: UUID(),
                name: "Alpha Field (Mock)",
                areaHa: 10.5,
                createdAt: Date(),
                cropType: mockCropType,
                plantationDate: Date().addingTimeInterval(-60*60*24*30),
                expectedHarvestDate: Date().addingTimeInterval(60*60*24*90),
                ndviScore: 0.82,
                lastSatelliteSync: Date()
            )
        ]
    }
    
    /// Fetches mock sensor readings.
    func fetchSensorReadings() async throws -> [SensorReading] {
        return [
            SensorReading(
                sensor_id: UUID(),
                time: Date(),
                temperature: 24.5,
                moisture: 45.2,
                humidity: 60.1
            )
        ]
    }
    
    /// Returns mock AI recommendations for UI Preview and testing.
    func fetchRecommendations(for fieldId: UUID) async throws -> [FieldRecommendation] {
        return [
            FieldRecommendation(
                id: UUID(), fieldId: fieldId, category: "Irrigation", priority: "high",
                advice: "Soil moisture is critically low at 0.19 m³/m³. Irrigate within the next 12 hours to prevent permanent wilting.",
                confidence: 0.91, status: "pending", ndviAtGeneration: 0.23, createdAt: Date()
            ),
            FieldRecommendation(
                id: UUID(), fieldId: fieldId, category: "Weather Alert", priority: "medium",
                advice: "Heavy rain of 14mm is forecast in 48 hours. Postpone fertilizer application until after the rain event.",
                confidence: 0.75, status: "pending", ndviAtGeneration: 0.23, createdAt: Date()
            ),
            FieldRecommendation(
                id: UUID(), fieldId: fieldId, category: "Plant Health", priority: "low",
                advice: "NDVI is stable at 0.23. Continue monitoring — health is below optimum but not declining.",
                confidence: 0.80, status: "pending", ndviAtGeneration: 0.23, createdAt: Date()
            )
        ]
    }
    
    /// Mock implementation for deleting a field.
    func deleteField(id: UUID) async throws {
        // Mock a successful deletion
    }
    
    /// Provides feedback on an AI recommendation to improve future context.
    func updateRecommendationFeedback(for fieldId: UUID, recommendationId: UUID, status: String) async throws -> FieldRecommendation {
        return FieldRecommendation(
            id: recommendationId, fieldId: fieldId, category: "Mock", priority: "low",
            advice: "Feedback received", confidence: 1.0, status: status, ndviAtGeneration: nil, createdAt: Date()
        )
    }
    
    /// Fetches the conversational history for a field from the AI backend.
    func fetchChatHistory(for fieldId: UUID) async throws -> [ChatMessage] {
        return [
            ChatMessage(id: UUID(), role: "model", content: "Hello! I am your AI Agronomist. How can I help you today?", createdAt: Date())
        ]
    }
    
    /// Submits a new user message to the AI and returns the response.
    func sendChatMessage(for fieldId: UUID, message: String) async throws -> ChatMessage {
        try await Task.sleep(nanoseconds: 1 * 1_000_000_000)
        return ChatMessage(id: UUID(), role: "model", content: "I've analyzed the conditions based on your message: \(message). Everything looks stable.", createdAt: Date())
    }
    
    func verifySensorConnection(deviceId: String) async throws -> (isVerified: Bool, message: String) {
        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
        
        // Demo Logic: 'ESP' codes succeed, others fail
        if deviceId.uppercased().contains("ESP") {
            return (true, "Hardware verified and active.")
        } else {
            return (false, "Hardware ID not found. Ensure your ESP32 is powered and connected via USB/MQTT.")
        }
    }
}
