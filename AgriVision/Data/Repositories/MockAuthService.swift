import Foundation

/// A mock implementation of `AuthService` for use in SwiftUI Previews and Unit Tests.
/// This allows us to test the UI and logic without depending on a live Firebase backend.
final class MockAuthService: AuthService {
    var currentUserID: String? { isLoggedInStub ? "mock-user" : nil }
    
    var shouldFail: Bool = false
    var isLoggedInStub: Bool = false
    private var displayName: String?
    
    init(isLoggedIn: Bool = false, shouldFail: Bool = false, displayName: String? = "Mock User") {
        self.isLoggedInStub = isLoggedIn
        self.shouldFail = shouldFail
        self.displayName = displayName
    }
    
    var isUserLoggedIn: Bool {
        return isLoggedInStub
    }
    
    var currentUserDisplayName: String? {
        return isLoggedInStub ? displayName : nil
    }

    var currentUserEmail: String? { isLoggedInStub ? "mock@agrivision.test" : nil }
    var isGoogleProviderLinked: Bool { isLoggedInStub }
    
    var currentUserPhotoURL: URL? {
        return nil // Mock with no photo by default, or could enable for testing
    }

    func updateDisplayName(_ name: String) async throws {
        if shouldFail { throw AgriVisionError.operationFailed }
        displayName = name
    }
    
    func signInWithGoogle() async throws {
        if shouldFail {
            throw AgriVisionError.unknown("Mock sign-in failed.")
        }
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        isLoggedInStub = true
    }

    func signIn(email: String, password: String) async throws {
        if shouldFail {
            throw AgriVisionError.wrongPassword
        }
        try await Task.sleep(nanoseconds: 1_000_000_000)
        isLoggedInStub = true
    }

    func signUp(email: String, password: String) async throws {
        if shouldFail {
            throw AgriVisionError.emailAlreadyInUse
        }
        try await Task.sleep(nanoseconds: 1_000_000_000)
        isLoggedInStub = true
    }
    
    func signOut() throws {
        if shouldFail {
            throw NSError(domain: "MockAuthService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Mock sign-out failed."])
        }
        isLoggedInStub = false
    }
    
    func sendEmailVerification() async throws {
        if shouldFail {
            throw AgriVisionError.unknown("Mock verification failed.")
        }
        try await Task.sleep(nanoseconds: 500_000_000)
    }
    
    func reloadUser() async throws {
        // Mock implementation
    }
    
    var isEmailVerified: Bool {
        return true
    }
    
    func resetPassword(email: String) async throws {
        if shouldFail {
            throw AgriVisionError.userNotFound
        }
        try await Task.sleep(nanoseconds: 500_000_000)
    }
    
    func linkGoogleAccount() async throws {
        if shouldFail {
            throw AgriVisionError.unknown("Link account failed")
        }
        try await Task.sleep(nanoseconds: 500_000_000)
    }
    
    func getIDToken(forceRefresh: Bool = false) async throws -> String {
        return "mock-firebase-token"
    }
}
