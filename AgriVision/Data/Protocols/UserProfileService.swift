import Foundation

/// Encapsulates user profile mutations that are not credential concerns.
///
/// Keeping this separate from `AuthService` ensures auth remains focused on
/// identity/credentials while profile enrichment can evolve independently (SRP).
protocol UserProfileService {
    /// Updates the current user's display name.
    /// - Parameter displayName: Name shown across the authenticated experience.
    func updateDisplayName(_ displayName: String) async throws
}
