import CoreLocation
import Foundation

final class NetworkAgriDataRepository: AgriDataService {
    private let apiClient: APIClient
    private let authService: AuthService
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(authService: AuthService, session: URLSession = .shared) {
        self.authService = authService
        apiClient = APIClient(authService: authService, session: session)
        decoder = JSONDecoder()
        encoder = JSONEncoder()
    }

    func bootstrapSession() async throws -> SessionBootstrap {
        let bootstrap: SessionBootstrap = try await apiClient.send(APIConstants.Endpoints.bootstrap, method: "POST")
        bootstrap.fields.forEach(cacheBoundaryIfPresent)
        return bootstrap
    }

    func fetchFields(includeArchived: Bool = false) async throws -> [Field] {
        let fields: [Field] = try await apiClient.send(
            APIConstants.Endpoints.fields,
            query: includeArchived ? [URLQueryItem(name: "include_archived", value: "true")] : []
        )
        return fields.map(fieldWithCachedBoundary)
    }

    func fetchDashboard(for fieldId: UUID) async throws -> DashboardSnapshot {
        try await apiClient.send(APIConstants.Endpoints.dashboard(fieldId))
    }

    func fetchSatelliteImage(for fieldId: UUID, kind: String) async throws -> Data {
        let safeKind = kind == "truecolor" ? "truecolor" : "ndvi"
        return try await apiClient.sendData("\(APIConstants.Endpoints.field(fieldId))/satellite/latest/\(safeKind)")
    }

    func fetchSensorReadings(for fieldId: UUID) async throws -> [SensorReading] {
        try await apiClient.send(APIConstants.Endpoints.readings(fieldId))
    }

    func fetchSensors(for fieldId: UUID) async throws -> [FieldSensor] {
        try await apiClient.send(APIConstants.Endpoints.assignSensor(to: fieldId))
    }

    func saveField(
        name: String,
        coordinates: [CLLocationCoordinate2D],
        areaHa: Double?,
        cropType: String?,
        plantationDate: Date?,
        expectedHarvestDate: Date?,
        sensors: [SensorConfig]?
    ) async throws -> Field {
        let points = coordinates.map { PointCoordinates(latitude: $0.latitude, longitude: $0.longitude) }
        let request = FieldCreateRequest(name: name, coordinates: points, areaHa: areaHa, cropType: cropType, plantationDate: plantationDate, expectedHarvestDate: expectedHarvestDate, sensors: sensors ?? [])
        let field: Field = try await apiClient.send(APIConstants.Endpoints.fields, method: "POST", body: request)
        let resolved = (field.coordinates?.count ?? 0) >= 3 ? field : field.replacingCoordinates(with: points)
        cacheBoundaryIfPresent(resolved)
        return resolved
    }

    func deleteField(id: UUID) async throws {
        try await apiClient.sendWithoutResponse(APIConstants.Endpoints.field(id), method: "DELETE")
        removeCachedBoundary(for: id)
    }

    func refreshFieldData(for fieldId: UUID) async throws {
        try await apiClient.sendWithoutResponse(APIConstants.Endpoints.dataRefresh(fieldId), method: "POST")
    }

    func fetchRecommendations(for fieldId: UUID) async throws -> [FieldRecommendation] {
        try await apiClient.send(APIConstants.Endpoints.recommendations(for: fieldId))
    }

    func refreshRecommendations(for fieldId: UUID) async throws {
        try await apiClient.sendWithoutResponse(APIConstants.Endpoints.recommendations(for: fieldId), method: "POST")
    }

    func updateRecommendationFeedback(for fieldId: UUID, recommendationId: UUID, status: String) async throws -> FieldRecommendation {
        try await apiClient.send(APIConstants.Endpoints.feedback(recommendationId), method: "POST", body: FeedbackRequest(status: status))
    }

    func recordRecommendationOutcome(for fieldId: UUID, recommendationId: UUID, outcome: String, notes: String?) async throws -> FieldRecommendation {
        try await apiClient.send(APIConstants.Endpoints.outcome(recommendationId), method: "POST", body: OutcomeRequest(outcome: outcome, notes: notes))
    }

    func fetchChatHistory(for fieldId: UUID) async throws -> [ChatMessage] {
        try await apiClient.send(APIConstants.Endpoints.chat(for: fieldId))
    }

    func fetchChatAttachment(fieldId: UUID, attachmentId: UUID) async throws -> Data {
        try await apiClient.sendData(APIConstants.Endpoints.chatAttachment(fieldId: fieldId, attachmentId: attachmentId))
    }

    func sendChatMessage(for fieldId: UUID, message: String, images: [ChatImageUpload], idempotencyKey: String) async throws -> ChatTurn {
        try await apiClient.sendMultipart(
            APIConstants.Endpoints.chat(for: fieldId),
            fields: ["message": message],
            files: images.map { MultipartFile(name: "images", filename: $0.filename, mimeType: $0.mimeType, data: $0.data) },
            idempotencyKey: idempotencyKey
        )
    }

    func verifySensorConnection(deviceId: String) async throws -> (isVerified: Bool, message: String) {
        let response: VerifyResponse = try await apiClient.send(APIConstants.Endpoints.verifySensor(deviceId: deviceId))
        return (response.isVerified, response.message)
    }

    func pairSensor(deviceId: String) async throws -> (isPaired: Bool, message: String) {
        let response: PairSensorResponse = try await apiClient.send(
            APIConstants.Endpoints.pairSensor,
            method: "POST",
            body: PairSensorRequest(deviceId: deviceId)
        )
        return (response.isPaired, response.message)
    }

    func assignSensor(_ sensor: SensorConfig, to fieldId: UUID) async throws {
        let _: AssignedSensorResponse = try await apiClient.send(
            APIConstants.Endpoints.assignSensor(to: fieldId),
            method: "POST",
            body: sensor
        )
    }

    func fetchWeatherSoil(for fieldId: UUID) async throws -> FieldWeatherSoil {
        try await apiClient.send("\(APIConstants.Endpoints.field(fieldId))/weather-soil")
    }

    private var boundaryCacheKey: String {
        "agrivision.field-boundaries.\(authService.currentUserID ?? "signed-out")"
    }

    private func cachedBoundaries() -> [String: [PointCoordinates]] {
        guard let data = UserDefaults.standard.data(forKey: boundaryCacheKey),
              let value = try? decoder.decode([String: [PointCoordinates]].self, from: data) else { return [:] }
        return value
    }

    private func fieldWithCachedBoundary(_ field: Field) -> Field {
        if let coordinates = field.coordinates, coordinates.count >= 3 {
            cacheBoundaryIfPresent(field)
            return field
        }
        guard let cached = cachedBoundaries()[field.id.uuidString.lowercased()] else { return field }
        return field.replacingCoordinates(with: cached)
    }

    private func cacheBoundaryIfPresent(_ field: Field) {
        guard let coordinates = field.coordinates, coordinates.count >= 3 else { return }
        var values = cachedBoundaries()
        values[field.id.uuidString.lowercased()] = coordinates
        if let data = try? encoder.encode(values) { UserDefaults.standard.set(data, forKey: boundaryCacheKey) }
    }

    private func removeCachedBoundary(for id: UUID) {
        var values = cachedBoundaries()
        values.removeValue(forKey: id.uuidString.lowercased())
        if let data = try? encoder.encode(values) { UserDefaults.standard.set(data, forKey: boundaryCacheKey) }
    }
}

private struct FieldCreateRequest: Encodable {
    let name: String
    let coordinates: [PointCoordinates]
    let areaHa: Double?
    let cropType: String?
    let plantationDate: Date?
    let expectedHarvestDate: Date?
    let sensors: [SensorConfig]

    enum CodingKeys: String, CodingKey {
        case name, coordinates, sensors
        case areaHa = "area_ha"
        case cropType = "crop_type"
        case plantationDate = "plantation_date"
        case expectedHarvestDate = "expected_harvest_date"
    }
}

private struct FeedbackRequest: Encodable { let status: String }
private struct OutcomeRequest: Encodable { let outcome: String; let notes: String? }

private struct VerifyResponse: Decodable {
    let isVerified: Bool
    let message: String
    enum CodingKeys: String, CodingKey { case isVerified = "is_verified", message }
}

private struct PairSensorRequest: Encodable {
    let deviceId: String
    enum CodingKeys: String, CodingKey { case deviceId = "device_id" }
}

private struct PairSensorResponse: Decodable {
    let isPaired: Bool
    let message: String
    enum CodingKeys: String, CodingKey { case isPaired = "is_paired", message }
}

private struct AssignedSensorResponse: Decodable { let id: UUID }
