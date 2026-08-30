import CoreLocation

protocol AgriDataService {
    func bootstrapSession() async throws -> SessionBootstrap
    func fetchFields(includeArchived: Bool) async throws -> [Field]
    func fetchDashboard(for fieldId: UUID) async throws -> DashboardSnapshot
    func fetchSatelliteImage(for fieldId: UUID, kind: String) async throws -> Data
    func fetchSensorReadings(for fieldId: UUID) async throws -> [SensorReading]
    func fetchSensors(for fieldId: UUID) async throws -> [FieldSensor]
    func saveField(name: String, coordinates: [CLLocationCoordinate2D], areaHa: Double?, cropType: String?, plantationDate: Date?, expectedHarvestDate: Date?, sensors: [SensorConfig]?) async throws -> Field
    func deleteField(id: UUID) async throws
    func refreshFieldData(for fieldId: UUID) async throws
    func fetchRecommendations(for fieldId: UUID) async throws -> [FieldRecommendation]
    func refreshRecommendations(for fieldId: UUID) async throws
    func fetchSeasonMemory(for fieldId: UUID) async throws -> SeasonMemory?
    func updateRecommendationFeedback(for fieldId: UUID, recommendationId: UUID, status: String) async throws -> FieldRecommendation
    func recordRecommendationOutcome(for fieldId: UUID, recommendationId: UUID, outcome: String, notes: String?) async throws -> FieldRecommendation
    func fetchChatHistory(for fieldId: UUID) async throws -> [ChatMessage]
    func fetchChatAttachment(fieldId: UUID, attachmentId: UUID) async throws -> Data
    func sendChatMessage(for fieldId: UUID, message: String, images: [ChatImageUpload], idempotencyKey: String) async throws -> ChatTurn
    func verifySensorConnection(deviceId: String) async throws -> (isVerified: Bool, message: String)
    func pairSensor(deviceId: String) async throws -> (isPaired: Bool, message: String)
    func assignSensor(_ sensor: SensorConfig, to fieldId: UUID) async throws
    func fetchWeatherSoil(for fieldId: UUID) async throws -> FieldWeatherSoil
}

extension AgriDataService {
    func fetchFields() async throws -> [Field] { try await fetchFields(includeArchived: false) }
}
