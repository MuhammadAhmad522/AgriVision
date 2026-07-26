import Foundation
import CoreLocation

/**
 This class provides "fake" or "mock" data for our app while we are still developing it,
 or if we don't have a real server setup yet.
 It conforms to the `AgriDataService` protocol, meaning it promises to provide a `fetchSensorReadings()` method.
 */
class MockAgriDataRepository: AgriDataService {
    
    private let mockCropType: String
    private let mockFieldID: UUID
    private let mockOwnerID: UUID
    
    init(
        mockCropType: String = "Wheat",
        mockFieldID: UUID = UUID(),
        mockOwnerID: UUID = UUID()
    ) {
        self.mockCropType = mockCropType
        self.mockFieldID = mockFieldID
        self.mockOwnerID = mockOwnerID
    }

    func bootstrapSession() async throws -> SessionBootstrap {
        let fields = try await fetchFields()
        return SessionBootstrap(
            user: BackendUser(id: mockOwnerID, firebaseUid: "mock-user", email: "mock@example.com"),
            fields: fields,
            activeFieldLimit: 5,
            activeFieldCount: fields.count
        )
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
            coordinates: coordinates.map {
                PointCoordinates(latitude: $0.latitude, longitude: $0.longitude)
            },
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
    func fetchFields(includeArchived: Bool = false) async throws -> [Field] {
        // Return a mock field to populate the dashboard UI
        return [
            Field(
                id: mockFieldID,
                ownerId: mockOwnerID,
                name: "Alpha Field (Mock)",
                coordinates: [
                    PointCoordinates(latitude: 31.5244, longitude: 74.3538),
                    PointCoordinates(latitude: 31.5240, longitude: 74.3610),
                    PointCoordinates(latitude: 31.5176, longitude: 74.3618),
                    PointCoordinates(latitude: 31.5169, longitude: 74.3543)
                ],
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
    func fetchSensorReadings(for fieldId: UUID) async throws -> [SensorReading] {
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

    func fetchSensors(for fieldId: UUID) async throws -> [FieldSensor] { [] }
    
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

    func refreshFieldData(for fieldId: UUID) async throws {}

    func fetchDashboard(for fieldId: UUID) async throws -> DashboardSnapshot {
        let fields = try await fetchFields()
        let field = fields[0]
        let weatherSoil = try await fetchWeatherSoil(for: fieldId)
        return DashboardSnapshot(
            field: field,
            sources: DashboardSources(
                satellite: SourceState(status: "available", lastUpdated: Date(), data: nil, message: nil),
                soil: SourceState(status: "available", lastUpdated: Date(), data: weatherSoil.soil, message: nil),
                weather: SourceState(status: "available", lastUpdated: Date(), data: weatherSoil.weather, message: nil),
                uvi: SourceState(status: "unavailable", lastUpdated: nil, data: nil, message: nil),
                sensors: SourceState(status: "available", lastUpdated: Date(), data: try await fetchSensorReadings(for: fieldId), message: nil)
            ),
            advisor: AdvisorSnapshot(
                status: "available",
                lastUpdated: Date(),
                message: nil,
                retryable: false,
                dataQuality: "good"
            ),
            recommendations: try await fetchRecommendations(for: fieldId)
        )
    }

    func fetchSatelliteImage(for fieldId: UUID, kind: String) async throws -> Data { Data() }
    
    /// Provides feedback on an AI recommendation to improve future context.
    func updateRecommendationFeedback(for fieldId: UUID, recommendationId: UUID, status: String) async throws -> FieldRecommendation {
        return FieldRecommendation(
            id: recommendationId, fieldId: fieldId, category: "Mock", priority: "low",
            advice: "Feedback received", confidence: 1.0, status: status, ndviAtGeneration: nil, createdAt: Date()
        )
    }

    func recordRecommendationOutcome(for fieldId: UUID, recommendationId: UUID, outcome: String, notes: String?) async throws -> FieldRecommendation {
        FieldRecommendation(
            id: recommendationId, fieldId: fieldId, category: "Mock", priority: "low",
            advice: "Outcome received", confidence: 1.0, status: "implemented", ndviAtGeneration: nil,
            createdAt: Date(), outcome: outcome, outcomeNotes: notes
        )
    }

    func refreshRecommendations(for fieldId: UUID) async throws {}
    
    /// Fetches the conversational history for a field from the AI backend.
    func fetchChatHistory(for fieldId: UUID) async throws -> [ChatMessage] {
        return [
            ChatMessage(id: UUID(), role: "model", content: "Hello! I am your AI Agronomist. How can I help you today?", createdAt: Date())
        ]
    }

    func fetchChatAttachment(fieldId: UUID, attachmentId: UUID) async throws -> Data { Data() }
    
    /// Submits a new user message to the AI and returns the response.
    func sendChatMessage(for fieldId: UUID, message: String, images: [ChatImageUpload], idempotencyKey: String) async throws -> ChatTurn {
        try await Task.sleep(nanoseconds: 1 * 1_000_000_000)
        return ChatTurn(
            userMessage: ChatMessage(id: UUID(), role: "user", content: message, status: "completed", attachments: [], createdAt: Date()),
            assistantMessage: ChatMessage(id: UUID(), role: "model", content: "I've analyzed the conditions based on your message: \(message). Everything looks stable.", status: "completed", attachments: [], createdAt: Date())
        )
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

    func pairSensor(deviceId: String) async throws -> (isPaired: Bool, message: String) {
        let verification = try await verifySensorConnection(deviceId: deviceId)
        return (verification.isVerified, verification.isVerified ? "Sensor paired and ready to assign to a field." : verification.message)
    }


    func assignSensor(_ sensor: SensorConfig, to fieldId: UUID) async throws {}
    
    /// Fetches mock satellite soil data and weather forecast for a field.
    func fetchWeatherSoil(for fieldId: UUID) async throws -> FieldWeatherSoil {
        return FieldWeatherSoil(
            fieldId: fieldId,
            soil: FieldWeatherSoil.SoilData(
                moisture: 0.38,
                surfaceTempC: 22.4,
                depthTempC: 19.8,
                source: "mock_satellite"
            ),
            weather: FieldWeatherSoil.WeatherData(
                current: FieldWeatherSoil.CurrentWeather(
                    tempC: 24.0,
                    humidity: 62.0,
                    description: "scattered clouds"
                ),
                forecastDays: [
                    FieldWeatherSoil.ForecastDay(date: "Mon", tempMaxC: 26.0, tempMinC: 18.0, rainMm: 0.0, description: "Sunny"),
                    FieldWeatherSoil.ForecastDay(date: "Tue", tempMaxC: 24.0, tempMinC: 16.0, rainMm: 2.5, description: "Light Rain"),
                    FieldWeatherSoil.ForecastDay(date: "Wed", tempMaxC: 22.0, tempMinC: 15.0, rainMm: 12.0, description: "Heavy Rain"),
                    FieldWeatherSoil.ForecastDay(date: "Thu", tempMaxC: 25.0, tempMinC: 17.0, rainMm: 0.0, description: "Sunny"),
                    FieldWeatherSoil.ForecastDay(date: "Fri", tempMaxC: 27.0, tempMinC: 18.0, rainMm: 0.5, description: "Scattered Clouds")
                ],
                source: "mock_forecast"
            )
        )
    }
}
