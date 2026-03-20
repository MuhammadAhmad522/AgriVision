import Foundation
import FirebaseAuth
import GoogleSignIn
import UIKit

/// Concrete implementation of `AuthService` using Firebase Authentication.
///
/// This class handles the specific details of the Firebase SDK and Google Sign-In SDK.
final class FirebaseAuthService: AuthService {
    
    init() {}

    /// Returns true if a user is currently signed in.
    var isUserLoggedIn: Bool {
        return Auth.auth().currentUser != nil
    }

    /// Returns the display name of the current user, if available.
    var currentUserDisplayName: String? {
        return Auth.auth().currentUser?.displayName
    }
    
    /// Returns the photo URL of the current user, if available.
    var currentUserPhotoURL: URL? {
        return Auth.auth().currentUser?.photoURL
    }

    /// Returns true if the user's email is verified.
    var isEmailVerified: Bool {
        return Auth.auth().currentUser?.isEmailVerified ?? false
    }

    private func getTopViewController() throws -> UIViewController {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            #if DEBUG
            print("Failed to resolve top view controller for Google sign-in flow.")
            #endif
            throw AgriVisionError.invalidInternalState
        }
        
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        return topController
    }

    /// Initiates the Google Sign-In flow.
    ///
    /// Uses the top-most view controller to present the Google Sign-In sheet.
    /// This uses the modern `GIDSignIn` async API.
    @MainActor
    func signInWithGoogle() async throws {
        let topController = try getTopViewController()

        do {
            // Ensure any previous session is cleared to force a fresh token fetch
            // which helps avoid "expired credential" errors.
            if GIDSignIn.sharedInstance.currentUser != nil {
                GIDSignIn.sharedInstance.signOut()
            }

            // Perform the sign-in flow using the modern async API.
            // Note: Make sure GIDClientID is set in Info.plist
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: topController)
            
            let user = result.user
            
            // Authenticate with Firebase using the Google credential.
            guard let idToken = user.idToken?.tokenString else {
                #if DEBUG
                print("Google Sign-In returned nil ID token during sign-in flow.")
                #endif
                throw AgriVisionError.invalidInternalState
            }
            
            let accessToken = user.accessToken.tokenString
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: accessToken)
            
            try await Auth.auth().signIn(with: credential)
        } catch {
            throw FirebaseAuthErrorMapper.map(error)
        }
    }

    /// Signs in with email and password.
    func signIn(email: String, password: String) async throws {
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            throw FirebaseAuthErrorMapper.map(error)
        }
    }

    /// Signs up a new user with email and password.
    func signUp(email: String, password: String) async throws {
        do {
            _ = try await Auth.auth().createUser(withEmail: email, password: password)
        } catch {
            throw FirebaseAuthErrorMapper.map(error)
        }
    }
    
    /// Sends an email verification link to the currently signed-in user.
    func sendEmailVerification() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AgriVisionError.userNotFound
        }
        try await user.sendEmailVerification()
    }
    
    /// Reloads the current user's data (e.g. email verification status).
    func reloadUser() async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await user.reload()
    }
    
    /// Sends a password reset email to the given address.
    func resetPassword(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            throw FirebaseAuthErrorMapper.map(error)
        }
    }

    /// Signs out from both Firebase and Google.
    ///
    /// Google session is always cleared locally to prevent stale-account reuse on next sign-in.
    /// If Firebase sign-out fails, a mapped domain error is still surfaced to the caller.
    func signOut() throws {
        defer { GIDSignIn.sharedInstance.signOut() }

        do {
            try Auth.auth().signOut()
        } catch {
            throw FirebaseAuthErrorMapper.map(error)
        }
    }
    
    /// Links the current user account with Google.
    @MainActor
    func linkGoogleAccount() async throws {
        let topController = try getTopViewController()

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: topController)
            let user = result.user
            
            guard let idToken = user.idToken?.tokenString else {
                #if DEBUG
                print("Google Sign-In returned nil ID token during account-link flow.")
                #endif
                throw AgriVisionError.invalidInternalState
            }
            
            let accessToken = user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            
            guard let currentUser = Auth.auth().currentUser else {
                throw AgriVisionError.userNotFound
            }
            
            let _ = try await currentUser.link(with: credential)
        } catch {
            throw FirebaseAuthErrorMapper.map(error)
        }
    }
}
