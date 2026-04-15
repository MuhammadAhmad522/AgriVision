import Foundation

/// Represents a single message in the AI Advisor autonomous chat.
/// Fetched from and sent to the FastAPI backend.
struct ChatMessage: Codable, Identifiable {
    let id: UUID
    let role: String // "user" or "model"
    let content: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case createdAt = "created_at"
    }
}

/// Request payload specifically used for POSTing a new chat message
struct ChatMessageRequest: Codable {
    let message: String
}
