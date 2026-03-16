import Foundation

enum AuthError: LocalizedError {
    case invalidInternalState // e.g. self is nil
    case userNotFound
    case wrongPassword
    case emailAlreadyInUse
    case invalidEmail
    case weakPassword
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidInternalState: return "An internal error occurred."
        case .userNotFound: return "No account found with this email."
        case .wrongPassword: return "Incorrect password."
        case .emailAlreadyInUse: return "This email is already associated with an account."
        case .invalidEmail: return "The email address is badly formatted."
        case .weakPassword: return "The password is too weak."
        case .unknown(let message): return message
        }
    }
}

/// Protocol defining authentication capabilities.
///
/// Follows Interface Segregation Principle (ISP) by keeping the interface focused on auth tasks.
/// ViewModels depend on this abstraction rather than concrete implementations (DIP).
protocol AuthService {
    /// Attempts to sign in with Google.
    /// - Returns: void on success, throws on error.
    func signInWithGoogle() async throws
    
    /// Signs in with email and password.
    /// - Parameters:
    ///   - email: The user's email address.
    ///   - password: The user's password.
    func signIn(email: String, password: String) async throws

    /// Signs up a new user with email and password.
    /// - Parameters:
    ///   - email: The user's email address.
    ///   - password: The user's password.
    ///   - name: The user's full name to be set as display name.
    func signUp(email: String, password: String, name: String) async throws
    
    /// Signs out the current user.
    func signOut() throws

    /// Fetches the sign-in methods allowed for the given email.
    func fetchSignInMethods(forEmail email: String) async throws -> [String]
    
    /// Links the current user account with Google.
    func linkGoogleAccount() async throws

    /// Returns true if a user is currently signed in.
    var isUserLoggedIn: Bool { get }
    
    /// Returns the display name of the current user, if available.
    var currentUserDisplayName: String? { get }
    
    /// Returns the photo URL of the current user, if available.
    var currentUserPhotoURL: URL? { get }
    
    /// Sends an email verification link to the currently signed-in user.
    func sendEmailVerification() async throws

    /// Reloads the current user's data (e.g. email verification status).
    func reloadUser() async throws
    
    /// Returns true if the user's email is verified.
    var isEmailVerified: Bool { get }

    /// Sends a password reset email to the given address.
    /// - Parameter email: The email address to send the password reset link to.
    func resetPassword(email: String) async throws
}
