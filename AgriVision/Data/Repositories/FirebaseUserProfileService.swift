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
            throw FirebaseAuthErrorMapper.map(error)
        }
    }
}
