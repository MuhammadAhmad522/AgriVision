import CoreLocation

/**
 A `protocol` in Swift is like a contract or a blueprint.
 It says: "Any class or struct that uses this protocol MUST have these specific methods."
 We use this so our ViewModels don't care *where* the data comes from (mock data or a real server),
 as long as it has a `fetchSensorReadings` method.
 */
protocol AgriDataService {
    /// Fetches sensor readings. 
    func fetchSensorReadings() async throws -> [SensorReading]
    
    /// Persists a new field boundary for the user with detailed metadata.
    func saveField(
        name: String,
        coordinates: [CLLocationCoordinate2D],
        areaHa: Double?,
        cropType: String?,
        plantationDate: Date?,
        expectedHarvestDate: Date?,
        sensors: [SensorConfig]?
    ) async throws -> Field
    
    /// Fetches all fields belonging to the current user, including satellite data.
    func fetchFields() async throws -> [Field]
    
    /// Deletes a specific field by its ID.
    func deleteField(id: UUID) async throws
    
    /// Fetches the latest AI recommendations for a given field.
    func fetchRecommendations(for fieldId: UUID) async throws -> [FieldRecommendation]
    
    /// Provides feedback on an AI recommendation to improve future context.
    func updateRecommendationFeedback(for fieldId: UUID, recommendationId: UUID, status: String) async throws -> FieldRecommendation
    
    /// Fetches the conversational history for a field from the AI backend.
    func fetchChatHistory(for fieldId: UUID) async throws -> [ChatMessage]
    
    /// Submits a new user message to the AI and returns the response.
    func sendChatMessage(for fieldId: UUID, message: String) async throws -> ChatMessage
    
    /// Verifies if a sensor device is active and reachable.
    func verifySensorConnection(deviceId: String) async throws -> (isVerified: Bool, message: String)
    
    /// Fetches the satellite soil data and weather forecast for a field.
    func fetchWeatherSoil(for fieldId: UUID) async throws -> FieldWeatherSoil
}
