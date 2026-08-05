import XCTest
@testable import AgriVision

final class ValidationServiceTests: XCTestCase {

    // MARK: - Email Validation

    func testValidateEmail_validEmails() throws {
        let valid = ["user@example.com", "test.user@domain.co", "user+tag@domain.org", "a@b.cd"]
        for email in valid {
            XCTAssertNoThrow(try InputValidator.validate(email: email), "Expected valid: \(email)")
        }
    }

    func testValidateEmail_invalidEmails() {
        let invalid = ["", "plainaddress", "@missing-user.com", "user@.com", "user@domain"]
        for email in invalid {
            XCTAssertThrowsError(try InputValidator.validate(email: email), "Expected invalid: \(email)") { error in
                XCTAssertTrue(error is ValidationError)
            }
        }
    }

    func testValidateEmail_emptyThrowsEmptyField() {
        XCTAssertThrowsError(try InputValidator.validate(email: "  ")) { error in
            XCTAssertEqual(error as? ValidationError, .emptyField("Email"))
        }
    }

    // MARK: - Password Validation

    func testValidatePassword_validPasswords() throws {
        let valid = ["Abcdef1!", "StrongP@ss1", "Valid123$%"]
        for pwd in valid {
            XCTAssertNoThrow(try InputValidator.validate(password: pwd), "Expected valid: \(pwd)")
        }
    }

    func testValidatePassword_tooShort() {
        XCTAssertThrowsError(try InputValidator.validate(password: "Ab1!")) { error in
            guard case .passwordTooShort(let min) = error as? ValidationError else {
                return XCTFail("Expected passwordTooShort")
            }
            XCTAssertEqual(min, 8)
        }
    }

    func testValidatePassword_missingUppercase() {
        XCTAssertThrowsError(try InputValidator.validate(password: "abcdef1!@")) { error in
            XCTAssertEqual(error as? ValidationError, .passwordComplexity)
        }
    }

    func testValidatePassword_missingLowercase() {
        XCTAssertThrowsError(try InputValidator.validate(password: "ABCDEF1!@")) { error in
            XCTAssertEqual(error as? ValidationError, .passwordComplexity)
        }
    }

    func testValidatePassword_missingNumber() {
        XCTAssertThrowsError(try InputValidator.validate(password: "Abcdefg!@")) { error in
            XCTAssertEqual(error as? ValidationError, .passwordComplexity)
        }
    }

    func testValidatePassword_missingSpecialCharacter() {
        XCTAssertThrowsError(try InputValidator.validate(password: "Abcdefg1")) { error in
            XCTAssertEqual(error as? ValidationError, .passwordComplexity)
        }
    }

    func testValidatePassword_emptyThrowsEmptyField() {
        XCTAssertThrowsError(try InputValidator.validate(password: "")) { error in
            XCTAssertEqual(error as? ValidationError, .emptyField("Password"))
        }
    }

    // MARK: - Field Validation

    func testValidateField_valid() throws {
        XCTAssertNoThrow(try InputValidator.validate(value: "John", fieldName: "First Name"))
    }

    func testValidateField_empty() {
        XCTAssertThrowsError(try InputValidator.validate(value: "  ", fieldName: "First Name")) { error in
            XCTAssertEqual(error as? ValidationError, .emptyField("First Name"))
        }
    }
}

final class ValidationErrorTests: XCTestCase {
    func testErrorDescriptions() {
        XCTAssertEqual(ValidationError.emptyField("Email").errorDescription, "Email cannot be empty.")
        XCTAssertEqual(ValidationError.invalidEmail.errorDescription, "Please enter a valid email address.")
        XCTAssertEqual(ValidationError.passwordTooShort(min: 8).errorDescription, "Password must be at least 8 characters long.")
        XCTAssertEqual(ValidationError.passwordComplexity.errorDescription, "Password must contain uppercase, lowercase, number, and special character.")
        XCTAssertEqual(ValidationError.passwordsDoNotMatch.errorDescription, "Passwords do not match.")
    }
}

final class ErrorPresentationTests: XCTestCase {

    func testAgriVisionErrorMessages() {
        let cases: [(AgriVisionError, String)] = [
            (.invalidInternalState, "An internal error occurred."),
            (.userNotFound, "No account found with this email."),
            (.wrongPassword, "Incorrect password."),
            (.invalidCredentials, "Your credentials are invalid. Please try signing in again."),
            (.emailAlreadyInUse, "This email is already associated with an account."),
            (.invalidEmail, "The email address is badly formatted."),
            (.weakPassword, "The password is too weak."),
            (.tooManyRequests, "Too many attempts. Please wait a moment and try again."),
            (.networkUnavailable, "Network error. Please check your internet connection and try again."),
            (.requestTimedOut, "The request timed out. Please try again."),
            (.passwordResetRequiresPasswordSignIn, "This account uses Google sign-in. Please continue with Google."),
            (.operationFailed, "We couldn\u{2019}t complete your request right now. Please try again."),
            (.unknown("Custom error"), "Custom error"),
        ]
        for (error, expected) in cases {
            XCTAssertEqual(error.userFacingMessage, expected, "Mismatch for \(error)")
        }
    }

    func testValidationErrorUserFacingMessage() {
        let error = ValidationError.emptyField("Email")
        XCTAssertEqual(error.userFacingMessage, "Email cannot be empty.")
    }

    func testBackendAPIErrorWithoutRequestID() {
        let error = BackendAPIError(code: "test", message: "Something failed", details: [], retryable: false, requestID: nil, statusCode: 400)
        XCTAssertEqual(error.userFacingMessage, "Something failed")
    }

    func testBackendAPIErrorWithRequestID() {
        let error = BackendAPIError(code: "test", message: "Failed", details: [], retryable: false, requestID: "req-abc123", statusCode: 400)
        XCTAssertEqual(error.userFacingMessage, "Failed Reference: req-abc1.")
    }

    func testUnknownErrorFallsBack() {
        struct SomeError: Error {}
        let error = SomeError()
        XCTAssertEqual(error.userFacingMessage, "We couldn\u{2019}t complete your request right now. Please try again later or contact App Admin.")
    }
}
