import Foundation

struct MultipartFile {
    let name: String
    let filename: String
    let mimeType: String
    let data: Data
}

struct BackendAPIError: LocalizedError {
    let code: String
    let message: String
    let details: [FieldError]
    let retryable: Bool
    let requestID: String?
    let statusCode: Int

    struct FieldError: Codable {
        let field: String?
        let message: String
    }

    var errorDescription: String? { message }
}

struct ErrorEnvelope: Decodable {
    let error: ErrorBody

    struct ErrorBody: Decodable {
        let code: String
        let message: String
        let details: [BackendAPIError.FieldError]?
        let retryable: Bool
        let requestId: String?

        enum CodingKeys: String, CodingKey {
            case code, message, details, retryable
            case requestId = "request_id"
        }
    }
}

final class APIClient {
    private let authService: AuthService
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(authService: AuthService, session: URLSession = .shared) {
        self.authService = authService
        self.session = session
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = APIDateCoding.fractional.date(from: value) ?? APIDateCoding.standard.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date")
        }
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    func send<Response: Decodable>(_ path: String, method: String = "GET", body: Encodable? = nil, query: [URLQueryItem] = []) async throws -> Response {
        let (data, response) = try await perform(path, method: method, body: body, query: query)
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            print("❌ Decoding Error for \(path): \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 Raw JSON payload: \(jsonString)")
            }
            throw BackendAPIError(code: "invalid_response", message: "The server returned data the app could not read.", details: [], retryable: true, requestID: response.value(forHTTPHeaderField: "X-Request-ID"), statusCode: response.statusCode)
        }
    }

    func sendWithoutResponse(_ path: String, method: String, body: Encodable? = nil) async throws {
        _ = try await perform(path, method: method, body: body, query: [])
    }

    func sendData(_ path: String) async throws -> Data {
        try await perform(path, method: "GET", body: nil, query: []).0
    }

    func sendMultipart<Response: Decodable>(
        _ path: String,
        fields: [String: String],
        files: [MultipartFile],
        idempotencyKey: String
    ) async throws -> Response {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        for (name, value) in fields {
            body.appendMultipart("--\(boundary)\r\n")
            body.appendMultipart("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.appendMultipart(value)
            body.appendMultipart("\r\n")
        }
        for file in files {
            body.appendMultipart("--\(boundary)\r\n")
            body.appendMultipart("Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.filename)\"\r\n")
            body.appendMultipart("Content-Type: \(file.mimeType)\r\n\r\n")
            body.append(file.data)
            body.appendMultipart("\r\n")
        }
        body.appendMultipart("--\(boundary)--\r\n")

        var request = URLRequest(url: APIConstants.baseURL.appendingPathComponent(path), timeoutInterval: 60)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        let (data, response) = try await perform(request)
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw BackendAPIError(code: "invalid_response", message: "The server returned data the app could not read.", details: [], retryable: true, requestID: response.value(forHTTPHeaderField: "X-Request-ID"), statusCode: response.statusCode)
        }
    }

    private func perform(_ path: String, method: String, body: Encodable?, query: [URLQueryItem]) async throws -> (Data, HTTPURLResponse) {
        let base = APIConstants.baseURL.appendingPathComponent(path)
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else { throw AgriVisionError.invalidInternalState }
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw AgriVisionError.invalidInternalState }

        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        if let body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            func execute(forceTokenRefresh: Bool) async throws -> (Data, HTTPURLResponse) {
                var authenticatedRequest = request
                authenticatedRequest.setValue("Bearer \(try await authService.getIDToken(forceRefresh: forceTokenRefresh))", forHTTPHeaderField: "Authorization")
                let (data, rawResponse) = try await session.data(for: authenticatedRequest)
                guard let response = rawResponse as? HTTPURLResponse else { throw AgriVisionError.operationFailed }
                return (data, response)
            }

            var (data, response) = try await execute(forceTokenRefresh: false)
            if response.statusCode == 401 {
                (data, response) = try await execute(forceTokenRefresh: true)
            }
            guard (200...299).contains(response.statusCode) else {
                if let envelope = try? decoder.decode(ErrorEnvelope.self, from: data) {
                    throw BackendAPIError(code: envelope.error.code, message: envelope.error.message, details: envelope.error.details ?? [], retryable: envelope.error.retryable, requestID: envelope.error.requestId, statusCode: response.statusCode)
                }
                throw BackendAPIError(code: "http_\(response.statusCode)", message: "The server could not complete this request.", details: [], retryable: response.statusCode >= 500, requestID: response.value(forHTTPHeaderField: "X-Request-ID"), statusCode: response.statusCode)
            }
            return (data, response)
        } catch let error as BackendAPIError {
            throw error
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            if error.code == .timedOut { throw AgriVisionError.requestTimedOut }
            if [.notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed].contains(error.code) {
                throw AgriVisionError.networkUnavailable
            }
            throw AgriVisionError.operationFailed
        }
    }
}

private extension Data {
    mutating func appendMultipart(_ string: String) {
        if let value = string.data(using: .utf8) { append(value) }
    }
}

enum APIDateCoding {
    static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void
    init(_ value: Encodable) { encodeValue = value.encode }
    func encode(to encoder: Encoder) throws { try encodeValue(encoder) }
}
