import XCTest
@testable import AgriVision

final class AuthViewModelTests: XCTestCase {

    @MainActor func test_initialTab_isLogin() {
        let vm = AuthViewModel()
        XCTAssertEqual(vm.selectedTab, .login)
    }

    @MainActor func test_switchToLogin() {
        let vm = AuthViewModel()
        vm.switchToSignup()
        vm.switchToLogin()
        XCTAssertEqual(vm.selectedTab, .login)
    }

    @MainActor func test_switchToSignup() {
        let vm = AuthViewModel()
        vm.switchToSignup()
        XCTAssertEqual(vm.selectedTab, .signup)
    }

    @MainActor func test_authCompleted_callsCallback() {
        let vm = AuthViewModel()
        var called = false
        vm.onAuthComplete = { called = true }
        vm.authCompleted()
        XCTAssertTrue(called)
    }
}

final class LoginViewModelTests: XCTestCase {

    @MainActor func test_initialState_loadsSavedEmail() {
        let prefs = MockPreferencesService()
        prefs.savedEmail = "saved@test.com"
        let vm = LoginViewModel(authService: MockAuthService(), preferencesService: prefs)
        XCTAssertEqual(vm.email, "saved@test.com")
        XCTAssertTrue(vm.rememberMe)
    }

    @MainActor func test_initialState_emptyWhenNoSavedEmail() {
        let vm = LoginViewModel(authService: MockAuthService(), preferencesService: MockPreferencesService())
        XCTAssertEqual(vm.email, "")
        XCTAssertFalse(vm.rememberMe)
    }

    @MainActor func test_login_success_callsOnLoginSuccess() {
        let auth = MockAuthService()
        let prefs = MockPreferencesService()
        let vm = LoginViewModel(authService: auth, preferencesService: prefs)
        vm.email = "test@example.com"
        vm.password = "ValidPass1!"
        var loginSuccess = false
        vm.onLoginSuccess = { loginSuccess = true }

        vm.login()

        let exp = expectation(description: "login")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { exp.fulfill() }
        wait(for: [exp], timeout: 3)

        XCTAssertTrue(loginSuccess)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    @MainActor func test_login_failure_setsError() {
        let auth = MockAuthService()
        auth.shouldFail = true
        let vm = LoginViewModel(authService: auth, preferencesService: MockPreferencesService())
        vm.email = "test@example.com"
        vm.password = "WrongPass1!"

        vm.login()

        let exp = expectation(description: "login fail")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { exp.fulfill() }
        wait(for: [exp], timeout: 3)

        XCTAssertFalse(vm.isLoading)
        XCTAssertNotNil(vm.errorMessage)
    }

    @MainActor func test_login_invalidEmail_setsError() async {
        let vm = LoginViewModel(authService: MockAuthService(), preferencesService: MockPreferencesService())
        vm.email = "not-an-email"
        vm.password = "ValidPass1!"

        vm.login()

        for _ in 0..<10 {
            await Task.yield()
        }

        XCTAssertFalse(vm.isLoading)
        XCTAssertNotNil(vm.errorMessage)
    }

    @MainActor func test_login_emptyPassword_setsError() async {
        let vm = LoginViewModel(authService: MockAuthService(), preferencesService: MockPreferencesService())
        vm.email = "test@example.com"
        vm.password = ""

        vm.login()

        for _ in 0..<10 {
            await Task.yield()
        }

        XCTAssertFalse(vm.isLoading)
        XCTAssertNotNil(vm.errorMessage)
    }

    @MainActor func test_rememberMe_persistsEmail() {
        let prefs = MockPreferencesService()
        let vm = LoginViewModel(authService: MockAuthService(), preferencesService: prefs)
        vm.email = "save@test.com"
        vm.rememberMe = true
        vm.password = "ValidPass1!"

        vm.login()

        let exp = expectation(description: "remember me")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { exp.fulfill() }
        wait(for: [exp], timeout: 3)

        XCTAssertEqual(prefs.savedEmail, "save@test.com")
    }

    @MainActor func test_rememberMe_off_clearsEmail() {
        let prefs = MockPreferencesService()
        prefs.savedEmail = "old@test.com"
        let vm = LoginViewModel(authService: MockAuthService(), preferencesService: prefs)
        vm.email = "new@test.com"
        vm.rememberMe = false
        vm.password = "ValidPass1!"

        vm.login()

        let exp = expectation(description: "no remember")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { exp.fulfill() }
        wait(for: [exp], timeout: 3)

        XCTAssertNil(prefs.savedEmail)
    }

    @MainActor func test_googleSignIn_success() {
        let auth = MockAuthService()
        let vm = LoginViewModel(authService: auth, preferencesService: MockPreferencesService())
        var success = false
        vm.onLoginSuccess = { success = true }

        vm.continueWithGoogle()

        let exp = expectation(description: "google sign in")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { exp.fulfill() }
        wait(for: [exp], timeout: 3)

        XCTAssertTrue(success)
        XCTAssertFalse(vm.isLoading)
    }

    @MainActor func test_googleSignIn_failure() {
        let auth = MockAuthService()
        auth.shouldFail = true
        let vm = LoginViewModel(authService: auth, preferencesService: MockPreferencesService())

        vm.continueWithGoogle()

        let exp = expectation(description: "google fail")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { exp.fulfill() }
        wait(for: [exp], timeout: 3)

        XCTAssertFalse(vm.isLoading)
        XCTAssertNotNil(vm.errorMessage)
    }

    @MainActor func test_forgotPassword_callsCallback() {
        let vm = LoginViewModel(authService: MockAuthService(), preferencesService: MockPreferencesService())
        var called = false
        vm.onForgotPassword = { called = true }
        vm.forgotPassword()
        XCTAssertTrue(called)
    }
}

final class SignupViewModelTests: XCTestCase {

    @MainActor func test_initialState_allEmpty() {
        let vm = SignupViewModel(authService: MockAuthService(), userProfileService: MockUserProfileService())
        XCTAssertEqual(vm.firstName, "")
        XCTAssertEqual(vm.lastName, "")
        XCTAssertEqual(vm.email, "")
        XCTAssertEqual(vm.password, "")
        XCTAssertEqual(vm.confirmPassword, "")
        XCTAssertFalse(vm.isLoading)
    }

    @MainActor func test_validateField_firstName_valid() {
        let vm = SignupViewModel(authService: MockAuthService(), userProfileService: MockUserProfileService())
        vm.validateField(.firstName, value: "John")
        XCTAssertNil(vm.firstNameError)
    }

    @MainActor func test_validateField_firstName_empty() {
        let vm = SignupViewModel(authService: MockAuthService(), userProfileService: MockUserProfileService())
        vm.validateField(.firstName, value: "  ")
        XCTAssertNotNil(vm.firstNameError)
    }

    @MainActor func test_validateField_email_valid() {
        let vm = SignupViewModel(authService: MockAuthService(), userProfileService: MockUserProfileService())
        vm.validateField(.email, value: "test@example.com")
        XCTAssertNil(vm.emailError)
    }

    @MainActor func test_validateField_email_invalid() {
        let vm = SignupViewModel(authService: MockAuthService(), userProfileService: MockUserProfileService())
        vm.validateField(.email, value: "bad")
        XCTAssertNotNil(vm.emailError)
    }

    @MainActor func test_validateField_password_valid() {
        let vm = SignupViewModel(authService: MockAuthService(), userProfileService: MockUserProfileService())
        vm.validateField(.password, value: "StrongP@ss1")
        XCTAssertNil(vm.passwordError)
    }

    @MainActor func test_validateField_password_weak() {
        let vm = SignupViewModel(authService: MockAuthService(), userProfileService: MockUserProfileService())
        vm.validateField(.password, value: "weak")
        XCTAssertNotNil(vm.passwordError)
    }

    @MainActor func test_validateField_confirmPassword_mismatch() {
        let vm = SignupViewModel(authService: MockAuthService(), userProfileService: MockUserProfileService())
        vm.password = "StrongP@ss1"
        vm.validateField(.confirmPassword, value: "Different1!")
        XCTAssertNotNil(vm.confirmPasswordError)
    }

    @MainActor func test_validateField_confirmPassword_match() {
        let vm = SignupViewModel(authService: MockAuthService(), userProfileService: MockUserProfileService())
        vm.password = "StrongP@ss1"
        vm.validateField(.confirmPassword, value: "StrongP@ss1")
        XCTAssertNil(vm.confirmPasswordError)
    }

    @MainActor func test_register_success() {
        let auth = MockAuthService()
        let profile = MockUserProfileService()
        let vm = SignupViewModel(authService: auth, userProfileService: profile)
        vm.firstName = "John"
        vm.lastName = "Doe"
        vm.email = "john@example.com"
        vm.password = "StrongP@ss1"
        vm.confirmPassword = "StrongP@ss1"

        var verificationCalled = false
        vm.onRequireVerification = { verificationCalled = true }

        vm.register()

        let exp = expectation(description: "register")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { exp.fulfill() }
        wait(for: [exp], timeout: 3)

        XCTAssertTrue(verificationCalled)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(profile.lastDisplayName, "John Doe")
    }

    @MainActor func test_register_failure() {
        let auth = MockAuthService()
        auth.shouldFail = true
        let profile = MockUserProfileService()
        let vm = SignupViewModel(authService: auth, userProfileService: profile)
        vm.firstName = "John"
        vm.lastName = "Doe"
        vm.email = "john@example.com"
        vm.password = "StrongP@ss1"
        vm.confirmPassword = "StrongP@ss1"

        vm.register()

        let exp = expectation(description: "register fail")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { exp.fulfill() }
        wait(for: [exp], timeout: 3)

        XCTAssertFalse(vm.isLoading)
        XCTAssertNotNil(vm.errorMessage)
    }

    @MainActor func test_register_validationErrorsPreventsSubmission() {
        let auth = MockAuthService()
        let vm = SignupViewModel(authService: auth, userProfileService: MockUserProfileService())
        vm.firstName = ""
        vm.email = "test@example.com"
        vm.password = "StrongP@ss1"
        vm.confirmPassword = "StrongP@ss1"

        vm.register()

        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    @MainActor func test_googleSignup_success() {
        let auth = MockAuthService()
        let vm = SignupViewModel(authService: auth, userProfileService: MockUserProfileService())
        var autoLoginCalled = false
        vm.onSignupAutoLogin = { autoLoginCalled = true }

        vm.continueWithGoogle()

        let exp = expectation(description: "google signup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { exp.fulfill() }
        wait(for: [exp], timeout: 3)

        XCTAssertTrue(autoLoginCalled)
        XCTAssertFalse(vm.isLoading)
    }

    @MainActor func test_googleSignup_failure() {
        let auth = MockAuthService()
        auth.shouldFail = true
        let vm = SignupViewModel(authService: auth, userProfileService: MockUserProfileService())

        vm.continueWithGoogle()

        let exp = expectation(description: "google signup fail")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { exp.fulfill() }
        wait(for: [exp], timeout: 3)

        XCTAssertFalse(vm.isLoading)
        XCTAssertNotNil(vm.errorMessage)
    }
}

final class ForgotPasswordViewModelTests: XCTestCase {

    @MainActor func test_initialState() {
        let vm = ForgotPasswordViewModel(authService: MockAuthService())
        XCTAssertEqual(vm.email, "")
        XCTAssertFalse(vm.isLoading)
    }

    @MainActor func test_sendResetLink_success() {
        let vm = ForgotPasswordViewModel(authService: MockAuthService())
        vm.email = "test@example.com"

        vm.sendResetLink()

        let exp = expectation(description: "reset link")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { exp.fulfill() }
        wait(for: [exp], timeout: 3)

        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
        XCTAssertNotNil(vm.successMessage)
    }

    @MainActor func test_sendResetLink_failure() {
        let auth = MockAuthService()
        auth.shouldFail = true
        let vm = ForgotPasswordViewModel(authService: auth)
        vm.email = "test@example.com"

        vm.sendResetLink()

        let exp = expectation(description: "reset link fail")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { exp.fulfill() }
        wait(for: [exp], timeout: 3)

        XCTAssertFalse(vm.isLoading)
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertNil(vm.successMessage)
    }

    @MainActor func test_sendResetLink_invalidEmail() async {
        let vm = ForgotPasswordViewModel(authService: MockAuthService())
        vm.email = "invalid"

        vm.sendResetLink()

        for _ in 0..<10 {
            await Task.yield()
        }

        XCTAssertFalse(vm.isLoading)
        XCTAssertNotNil(vm.errorMessage)
    }

    @MainActor func test_back() {
        let vm = ForgotPasswordViewModel(authService: MockAuthService())
        var called = false
        vm.onBack = { called = true }
        vm.back()
        XCTAssertTrue(called)
    }
}
