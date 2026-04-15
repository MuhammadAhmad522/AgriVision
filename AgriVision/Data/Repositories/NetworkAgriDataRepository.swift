import Foundation
import CoreLocation

/**
 `NetworkAgriDataRepository` is the production implementation of `AgriDataService`.
 It uses `URLSession` with `async/await` to talk to our FastAPI backend.
 
 - Follows **Dependency Inversion**: It only knows about the `AuthService` protocol to fetch tokens.
 - Follows **Single Responsibility**: Its only job is to translate domain requests into HTTP calls.
 */
class NetworkAgriDataRepository: AgriDataService {
    
    private let authService: AuthService
    private let session: URLSession
    
    /// The decoder is configured to handle snake_case from Python and ISO8601 dates.
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    /// The encoder is configured to handle the backend's snake_case requirements.
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    init(authService: AuthService, session: URLSession = .shared) {
        self.authService = authService
        self.session = session
    }
    
    // MARK: - AgriDataService Implementation
    
    /// Fetches all fields belonging to the current user.
    func fetchFields() async throws -> [Field] {
        let url = APIConstants.baseURL.appendingPathComponent(APIConstants.Endpoints.fields)
        let request = try await authenticatedRequest(for: url, method: "GET")
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        
        return try decoder.decode([Field].self, from: data)
    }
    
    /// Fetches the latest sensor readings from the backend.
    func fetchSensorReadings() async throws -> [SensorReading] {
        let url = APIConstants.baseURL.appendingPathComponent(APIConstants.Endpoints.readings)
        let request = try await authenticatedRequest(for: url, method: "GET")
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        
        // Note: The backend returns a list of telemetry rows mapped to SensorReadingDB schema
        return try decoder.decode([SensorReading].self, from: data)
    }
    
    /// Persists a new field boundary coordinates and metadata to the backend.
    func saveField(
        name: String,
        coordinates: [CLLocationCoordinate2D],
        areaHa: Double?,
        cropType: String?,
        plantationDate: Date?,
        expectedHarvestDate: Date?,
        sensors: [SensorConfig]?
    ) async throws -> Field {
        let url = APIConstants.baseURL.appendingPathComponent(APIConstants.Endpoints.fields)
        var request = try await authenticatedRequest(for: url, method: "POST")
        
        // Map to our backend's FieldCreate schema
        let points = coordinates.map { PointCoordinates(latitude: $0.latitude, longitude: $0.longitude) }
        let body = FieldCreateRequest(
            name: name,
            coordinates: points,
            areaHa: areaHa,
            cropType: cropType,
            plantationDate: plantationDate,
            expectedHarvestDate: expectedHarvestDate,
            sensors: sensors
        )
        
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        
        return try decoder.decode(Field.self, from: data)
    }
    
    /// Deletes a specific field by its ID.
    func deleteField(id: UUID) async throws {
        let path = APIConstants.Endpoints.fields + id.uuidString.lowercased()
        let url = APIConstants.baseURL.appendingPathComponent(path)
        let request = try await authenticatedRequest(for: url, method: "DELETE")
        
        let (_, response) = try await session.data(for: request)
        try validate(response: response)
    }
    
    /// Fetches the latest AI-generated recommendations for a specific field.
    func fetchRecommendations(for fieldId: UUID) async throws -> [FieldRecommendation] {
        let path = APIConstants.Endpoints.recommendations(for: fieldId)
        let url = APIConstants.baseURL.appendingPathComponent(path)
        let request = try await authenticatedRequest(for: url, method: "GET")
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        
        return try decoder.decode([FieldRecommendation].self, from: data)
    }
    
    /// Provides feedback on an AI recommendation to improve future context.
    func updateRecommendationFeedback(for fieldId: UUID, recommendationId: UUID, status: String) async throws -> FieldRecommendation {
        let path = APIConstants.Endpoints.feedback(for: fieldId, recommendationId: recommendationId)
        let url = APIConstants.baseURL.appendingPathComponent(path)
        var request = try await authenticatedRequest(for: url, method: "PUT")
        
        struct FeedbackPayload: Encodable { let status: String }
        let payload = FeedbackPayload(status: status)
        
        request.httpBody = try encoder.encode(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        
        // Return dummy model since the endpoint returns a trimmed dict, not a full FieldRecommendation,
        // or rely on fetching again in the view model.
        return FieldRecommendation(id: recommendationId, fieldId: fieldId, category: "", priority: "", advice: "", confidence: 1.0, status: status, ndviAtGeneration: nil, createdAt: Date())
    }
    
    /// Fetches the conversational history for a field from the AI backend.
    func fetchChatHistory(for fieldId: UUID) async throws -> [ChatMessage] {
        let path = APIConstants.Endpoints.chat(for: fieldId)
        let url = APIConstants.baseURL.appendingPathComponent(path)
        let request = try await authenticatedRequest(for: url, method: "GET")
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        
        return try decoder.decode([ChatMessage].self, from: data)
    }
    
    /// Submits a new user message to the AI and returns the response.
    func sendChatMessage(for fieldId: UUID, message: String) async throws -> ChatMessage {
        let path = APIConstants.Endpoints.chat(for: fieldId)
        let url = APIConstants.baseURL.appendingPathComponent(path)
        var request = try await authenticatedRequest(for: url, method: "POST")
        
        request.httpBody = try encoder.encode(ChatMessageRequest(message: message))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        
        return try decoder.decode(ChatMessage.self, from: data)
    }
    
    // MARK: - Generic API Support Models
    
    /// Request model for creating a field, matching the backend's `FieldCreate` pydantic model.
    private struct FieldCreateRequest: Encodable {
        let name: String
        let coordinates: [PointCoordinates]
        let areaHa: Double?
        let cropType: String?
        let plantationDate: Date?
        let expectedHarvestDate: Date?
        let sensors: [SensorConfig]?
        
        enum CodingKeys: String, CodingKey {
            case name
            case coordinates
            case areaHa = "area_ha"
            case cropType = "crop_type"
            case plantationDate = "plantation_date"
            case expectedHarvestDate = "expected_harvest_date"
            case sensors
        }
    }
    
    // MARK: - Private Helpers
    
    /// Creates a base URLRequest with the necessary Firebase Authorization header.
    private func authenticatedRequest(for url: URL, method: String) async throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Get the latest Firebase ID Token
        let token = try await authService.getIDToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return request
    }
    
    /// Validates the HTTP response status code.
    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgriVisionError.operationFailed
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            #if DEBUG
            print("HTTP Error: \(httpResponse.statusCode)")
            #endif
            
            if httpResponse.statusCode == 401 {
                throw AgriVisionError.invalidCredentials
            }
        }
    }
    
    /// Verifies if a sensor device is active and reachable.
    func verifySensorConnection(deviceId: String) async throws -> (isVerified: Bool, message: String) {
        let path = APIConstants.Endpoints.verifySensor(deviceId: deviceId)
        let url = APIConstants.baseURL.appendingPathComponent(path)
        let request = try await authenticatedRequest(for: url, method: "GET")
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        
        struct VerifyResponse: Decodable {
            let is_verified: Bool
            let message: String
        }
        
        let result = try decoder.decode(VerifyResponse.self, from: data)
        return (result.is_verified, result.message)
    }
}
