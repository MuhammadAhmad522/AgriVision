import XCTest
@testable import AgriVision

// MARK: - Mock URL Protocol

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            XCTFail("No handler set")
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Mock Auth Service for APIClient

final class MockTokenAuthService: AuthService {
    var currentUserID: String? { "mock-user" }
    var shouldFailToken: Bool = false
    var isUserLoggedIn: Bool = true
    var currentUserDisplayName: String? { "Mock" }
    var currentUserEmail: String? { "mock@test.com" }
    var isGoogleProviderLinked: Bool { false }
    var currentUserPhotoURL: URL? { nil }
    var isEmailVerified: Bool { true }
    var getIDTokenImpl: ((Bool) async throws -> String)?

    func signInWithGoogle() async throws {}
    func signIn(email: String, password: String) async throws {}
    func signUp(email: String, password: String) async throws {}
    func signOut() throws {}
    func linkGoogleAccount() async throws {}
    func updateDisplayName(_ name: String) async throws {}
    func sendEmailVerification() async throws {}
    func reloadUser() async throws {}
    func resetPassword(email: String) async throws {}

    func getIDToken(forceRefresh: Bool) async throws -> String {
        if let impl = getIDTokenImpl {
            return try await impl(forceRefresh)
        }
        if shouldFailToken { throw AgriVisionError.operationFailed }
        return "mock-token"
    }
}

final class APIClientTests: XCTestCase {

    private var client: APIClient!
    private var authService: MockTokenAuthService!
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        authService = MockTokenAuthService()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        client = APIClient(authService: authService, session: session)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        client = nil
        authService = nil
        session = nil
        super.tearDown()
    }

    func test_send_success() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """
            {"id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F", "name": "Field 1", "area_ha": 10.5, "created_at": "2024-01-01T00:00:00.000Z", "status": "active", "agro_status": "pending", "agro_retryable": true, "owner_id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"}
            """.data(using: .utf8)!
            return (response, data)
        }

        struct EchoResponse: Decodable {
            let name: String
            let areaHa: Double
            enum CodingKeys: String, CodingKey {
                case name
                case areaHa = "area_ha"
            }
        }

        let result: EchoResponse = try await client.send("/api/fields")
        XCTAssertEqual(result.name, "Field 1")
        XCTAssertEqual(result.areaHa, 10.5)
    }

    func test_send_unauthorized_triggersTokenRefresh() async throws {
        var tokenRefreshCount = 0
        authService.getIDTokenImpl = { forceRefresh in
            tokenRefreshCount += 1
            return "refreshed-token"
        }

        var callCount = 0
        MockURLProtocol.requestHandler = { request in
            callCount += 1
            let statusCode = callCount == 1 ? 401 : 200
            let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            let data = "{}".data(using: .utf8)!
            return (response, data)
        }

        struct EmptyResponse: Decodable {}
        let _: EmptyResponse = try await client.send("/api/fields")

        XCTAssertEqual(callCount, 2)
        // getIDToken is called once for the initial request and again for the 401 retry
        XCTAssertEqual(tokenRefreshCount, 2)
    }

    func test_send_serverError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: ["X-Request-ID": "req-123"])!
            let data = """
            {"error": {"code": "internal_error", "message": "Server error", "details": [], "retryable": true, "request_id": "req-123"}}
            """.data(using: .utf8)!
            return (response, data)
        }

        struct EmptyResponse: Decodable {}
        do {
            let _: EmptyResponse = try await client.send("/api/fields")
            XCTFail("Expected error")
        } catch let error as BackendAPIError {
            XCTAssertEqual(error.statusCode, 500)
            XCTAssertEqual(error.code, "internal_error")
            XCTAssertTrue(error.retryable)
            XCTAssertEqual(error.requestID, "req-123")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_send_networkError_returnsNetworkUnavailable() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        struct EmptyResponse: Decodable {}
        do {
            let _: EmptyResponse = try await client.send("/api/fields")
            XCTFail("Expected error")
        } catch let error as AgriVisionError {
            XCTAssertEqual(error, .networkUnavailable)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_send_timeoutError() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.timedOut)
        }

        struct EmptyResponse: Decodable {}
        do {
            let _: EmptyResponse = try await client.send("/api/fields")
            XCTFail("Expected error")
        } catch let error as AgriVisionError {
            XCTAssertEqual(error, .requestTimedOut)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_send_invalidResponse() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "not-json".data(using: .utf8)!
            return (response, data)
        }

        struct EmptyResponse: Decodable {}
        do {
            let _: EmptyResponse = try await client.send("/api/fields")
            XCTFail("Expected error")
        } catch let error as BackendAPIError {
            XCTAssertEqual(error.code, "invalid_response")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_sendData_returnsRawData() async throws {
        let expectedData = "raw-binary".data(using: .utf8)!
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, expectedData)
        }

        let data = try await client.sendData("/api/image")
        XCTAssertEqual(data, expectedData)
    }

    func test_authorizationHeader_isSet() async throws {
        MockURLProtocol.requestHandler = { request in
            let authHeader = request.value(forHTTPHeaderField: "Authorization")
            XCTAssertEqual(authHeader, "Bearer mock-token")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "{}".data(using: .utf8)!
            return (response, data)
        }

        struct EmptyResponse: Decodable {}
        let _: EmptyResponse = try await client.send("/api/fields")
    }

    func test_requestIDHeader_isSet() async throws {
        MockURLProtocol.requestHandler = { request in
            let requestID = request.value(forHTTPHeaderField: "X-Request-ID")
            XCTAssertNotNil(requestID)
            XCTAssertFalse(requestID!.isEmpty)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "{}".data(using: .utf8)!
            return (response, data)
        }

        struct EmptyResponse: Decodable {}
        let _: EmptyResponse = try await client.send("/api/fields")
    }

    func test_sendMultipart_success() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            let contentType = request.value(forHTTPHeaderField: "Content-Type")!
            XCTAssertTrue(contentType.contains("multipart/form-data"))
            XCTAssertNotNil(request.value(forHTTPHeaderField: "Idempotency-Key"))

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """
            {"id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F", "role": "user", "content": "OK", "status": "completed", "attachments": [], "created_at": "2024-01-01T00:00:00.000Z"}
            """.data(using: .utf8)!
            return (response, data)
        }

        let result: ChatMessage = try await client.sendMultipart(
            "/api/chat",
            fields: ["message": "Hello"],
            files: [],
            idempotencyKey: "key-123"
        )
        XCTAssertEqual(result.role, "user")
        XCTAssertEqual(result.content, "OK")
    }

    func test_sendWithoutResponse_success() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        try await client.sendWithoutResponse("/api/fields/delete", method: "DELETE")
    }
}
