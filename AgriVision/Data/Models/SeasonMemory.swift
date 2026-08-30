import Foundation

/// The AI advisor's compressed, whole-season narrative for a field's current crop cycle —
/// distinct from individual recommendations, this is the running "crop journal" fusing
/// satellite, sensor, farmer-reported, and agronomist-guided context over time.
struct SeasonMemory: Codable, Equatable {
    let fieldId: UUID
    let seasonStartedAt: Date
    var narrative: String? = nil
    var keyEvents: [SeasonKeyEvent] = []

    enum CodingKeys: String, CodingKey {
        case fieldId = "field_id"
        case seasonStartedAt = "season_started_at"
        case narrative
        case keyEvents = "key_events"
    }
}

struct SeasonKeyEvent: Codable, Equatable, Identifiable {
    var id: String { "\(date ?? "")-\(description ?? "")" }
    let date: String?
    let description: String?
}
