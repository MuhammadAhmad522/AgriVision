import Foundation

final class MockUserProfileService: UserProfileService {
    var shouldFail: Bool = false
    private(set) var lastDisplayName: String?

    func updateDisplayName(_ displayName: String) async throws {
        if shouldFail {
            throw AgriVisionError.unknown("Mock profile update failed.")
        }
        lastDisplayName = displayName
    }
}
