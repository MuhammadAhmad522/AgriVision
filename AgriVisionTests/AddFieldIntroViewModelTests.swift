import XCTest
@testable import AgriVision

final class AddFieldIntroViewModelTests: XCTestCase {

    // MARK: - Tests with MockAuthService (hardcoded "Mock User")

    func test_initialState_withDisplayName() {
        let auth = MockAuthService(isLoggedIn: true)
        let vm = AddFieldIntroViewModel(authService: auth)

        XCTAssertEqual(vm.userName, "Mock")
        // MockAuthService has displayName "Mock User" - ViewModel uses last name initial
        XCTAssertEqual(vm.profileInitial, "U")
        XCTAssertNil(vm.profileImageURL)
    }

    func test_initialState_withoutDisplayName() {
        let auth = MockAuthService(isLoggedIn: false)
        let vm = AddFieldIntroViewModel(authService: auth)

        XCTAssertEqual(vm.userName, "User")
        XCTAssertEqual(vm.profileInitial, "U")
        XCTAssertNil(vm.profileImageURL)
    }

    // MARK: - Custom inline mocks for custom display names

    func test_initialState_singleNameComponent() {
        let auth = MockAuthServiceWithName(displayName: "John")
        let vm = AddFieldIntroViewModel(authService: auth)

        XCTAssertEqual(vm.userName, "John")
        XCTAssertEqual(vm.profileInitial, "J")
    }

    func test_initialState_threeNameComponents() {
        let auth = MockAuthServiceWithName(displayName: "John Michael Smith")
        let vm = AddFieldIntroViewModel(authService: auth)

        XCTAssertEqual(vm.userName, "John")
        XCTAssertEqual(vm.profileInitial, "S")
    }

    func test_initialState_emptyName() {
        let auth = MockAuthServiceWithName(displayName: nil)
        let vm = AddFieldIntroViewModel(authService: auth)

        XCTAssertEqual(vm.userName, "User")
        XCTAssertEqual(vm.profileInitial, "U")
    }

    // MARK: - Action

    func test_addFieldAction_callsCallback() {
        let auth = MockAuthService(isLoggedIn: true)
        let vm = AddFieldIntroViewModel(authService: auth)

        var callbackCalled = false
        vm.onAddFieldTapped = { callbackCalled = true }

        vm.addFieldAction()

        XCTAssertTrue(callbackCalled)
    }
}

// MARK: - Custom Mock AuthService with configurable display name

final class MockAuthServiceWithName: AuthService {
    let displayName: String?

    init(displayName: String?) {
        self.displayName = displayName
    }

    var currentUserID: String? { displayName != nil ? "mock-user" : nil }
    var isUserLoggedIn: Bool { displayName != nil }
    var currentUserDisplayName: String? { displayName }
    var currentUserEmail: String? { displayName != nil ? "mock@agrivision.test" : nil }
    var isGoogleProviderLinked: Bool { displayName != nil }
    var currentUserPhotoURL: URL? { nil }
    var isEmailVerified: Bool { true }
    var shouldFail: Bool = false

    func signInWithGoogle() async throws {}
    func signIn(email: String, password: String) async throws {}
    func signUp(email: String, password: String) async throws {}
    func signOut() throws {}
    func linkGoogleAccount() async throws {}
    func updateDisplayName(_ name: String) async throws {}
    func sendEmailVerification() async throws {}
    func reloadUser() async throws {}
    func resetPassword(email: String) async throws {}
    func getIDToken(forceRefresh: Bool = false) async throws -> String { "mock-token" }
}
