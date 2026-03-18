import Foundation
import FirebaseAuth

/// Firebase-backed implementation of profile operations for the authenticated user.
final class FirebaseUserProfileService: UserProfileService {
    func updateDisplayName(_ displayName: String) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw AgriVisionError.userNotFound
        }

        let changeRequest = currentUser.createProfileChangeRequest()
        changeRequest.displayName = displayName

        do {
            try await changeRequest.commitChanges()
        } catch {
            throw mapError(error)
        }
    }

    private func mapError(_ error: Error) -> AgriVisionError {
        let nsError = error as NSError

        if nsError.domain == AuthErrorDomain,
           let code = AuthErrorCode(rawValue: nsError.code) {
            switch code {
            case .userNotFound: return .userNotFound
            case .networkError: return .networkUnavailable
            case .tooManyRequests: return .tooManyRequests
            default: break
            }
        }

        return .unknown(error.localizedDescription)
    }
}
