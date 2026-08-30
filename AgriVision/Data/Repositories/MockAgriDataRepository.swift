import Foundation
import CoreLocation

/**
 This class provides "fake" or "mock" data for our app while we are still developing it,
 or if we don't have a real server setup yet.
 It conforms to the `AgriDataService` protocol, meaning it promises to provide a `fetchSensorReadings()` method.
 */
class MockAgriDataRepository: AgriDataService {
    
    var shouldFail: Bool = false
    var failOnMethods: Set<String> = []

    private let mockCropType: String
    private let mockFieldID: UUID
    private let mockOwnerID: UUID

    enum MockError: Error, LocalizedError {
        case simulatedError(String)
        var errorDescription: String? {
            switch self { case .simulatedError(let msg): return msg }
        }
    }

    private func maybeThrow(_ method: String, _ file: String = #function) async throws {
        if shouldFail || failOnMethods.contains(method) {
            throw MockError.simulatedError("Simulated error in \(method)")
        }
    }

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
        try await maybeThrow("bootstrapSession")
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
        try await maybeThrow("saveField")
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
        try await maybeThrow("fetchFields")
        return []
    }


    
    /// Fetches mock sensor readings.
    func fetchSensorReadings(for fieldId: UUID) async throws -> [SensorReading] {
        try await maybeThrow("fetchSensorReadings")
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

    func fetchSensors(for fieldId: UUID) async throws -> [FieldSensor] {
        try await maybeThrow("fetchSensors")
        return []
    }
    
    /// Returns mock AI recommendations for UI Preview and testing.
    func fetchRecommendations(for fieldId: UUID) async throws -> [FieldRecommendation] {
        try await maybeThrow("fetchRecommendations")
        return []
    }
    
    /// Mock implementation for deleting a field.
    func deleteField(id: UUID) async throws {
        try await maybeThrow("deleteField")
    }

    func refreshFieldData(for fieldId: UUID) async throws {
        try await maybeThrow("refreshFieldData")
    }

    func fetchDashboard(for fieldId: UUID) async throws -> DashboardSnapshot {
        try await maybeThrow("fetchDashboard")
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
                sensors: SourceState(status: "available", lastUpdated: Date(), data: try await fetchSensorReadings(for: fieldId), message: nil),
                sensorFleet: []
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

    func fetchSatelliteImage(for fieldId: UUID, kind: String) async throws -> Data {
        try await maybeThrow("fetchSatelliteImage")
        return Data()
    }
    
    /// Provides feedback on an AI recommendation to improve future context.
    func updateRecommendationFeedback(for fieldId: UUID, recommendationId: UUID, status: String) async throws -> FieldRecommendation {
        try await maybeThrow("updateRecommendationFeedback")
        return FieldRecommendation(
            id: recommendationId, fieldId: fieldId, category: "Mock", priority: "low",
            advice: "Feedback received", confidence: 1.0, status: status, ndviAtGeneration: nil, createdAt: Date()
        )
    }

    func recordRecommendationOutcome(for fieldId: UUID, recommendationId: UUID, outcome: String, notes: String?) async throws -> FieldRecommendation {
        try await maybeThrow("recordRecommendationOutcome")
        return FieldRecommendation(
            id: recommendationId, fieldId: fieldId, category: "Mock", priority: "low",
            advice: "Outcome received", confidence: 1.0, status: "implemented", ndviAtGeneration: nil,
            createdAt: Date(), outcome: outcome, outcomeNotes: notes
        )
    }

    func refreshRecommendations(for fieldId: UUID) async throws {
        try await maybeThrow("refreshRecommendations")
    }

    func fetchSeasonMemory(for fieldId: UUID) async throws -> SeasonMemory? {
        try await maybeThrow("fetchSeasonMemory")
        return nil
    }
    
    /// Fetches the conversational history for a field from the AI backend.
    func fetchChatHistory(for fieldId: UUID) async throws -> [ChatMessage] {
        try await maybeThrow("fetchChatHistory")
        return [
            ChatMessage(id: UUID(), role: "model", content: "Hello! I am your AI Agronomist. How can I help you today?", createdAt: Date())
        ]
    }

    func fetchChatAttachment(fieldId: UUID, attachmentId: UUID) async throws -> Data {
        try await maybeThrow("fetchChatAttachment")
        return Data()
    }
    
    /// Submits a new user message to the AI and returns the response.
    func sendChatMessage(for fieldId: UUID, message: String, images: [ChatImageUpload], idempotencyKey: String) async throws -> ChatTurn {
        try await maybeThrow("sendChatMessage")
        try await Task.sleep(nanoseconds: 1 * 1_000_000_000)
        return ChatTurn(
            userMessage: ChatMessage(id: UUID(), role: "user", content: message, status: "completed", attachments: [], createdAt: Date()),
            assistantMessage: ChatMessage(id: UUID(), role: "model", content: "I've analyzed the conditions based on your message: \(message). Everything looks stable.", status: "completed", attachments: [], createdAt: Date())
        )
    }
    
    func verifySensorConnection(deviceId: String) async throws -> (isVerified: Bool, message: String) {
        try await maybeThrow("verifySensorConnection")
        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
        
        // Demo Logic: 'ESP' codes succeed, others fail
        if deviceId.uppercased().contains("ESP") {
            return (true, "Hardware verified and active.")
        } else {
            return (false, "Hardware ID not found. Ensure your ESP32 is powered and connected via USB/MQTT.")
        }
    }

    func pairSensor(deviceId: String) async throws -> (isPaired: Bool, message: String) {
        try await maybeThrow("pairSensor")
        let verification = try await verifySensorConnection(deviceId: deviceId)
        return (verification.isVerified, verification.isVerified ? "Sensor paired and ready to assign to a field." : verification.message)
    }


    func assignSensor(_ sensor: SensorConfig, to fieldId: UUID) async throws {
        try await maybeThrow("assignSensor")
    }
    
    /// Fetches mock satellite soil data and weather forecast for a field.
    func fetchWeatherSoil(for fieldId: UUID) async throws -> FieldWeatherSoil {
        try await maybeThrow("fetchWeatherSoil")
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
