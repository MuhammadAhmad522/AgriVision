import Foundation

struct UserNotification: Codable, Identifiable {
    let id: UUID
    let title: String
    let body: String
    let referenceId: String?
    let referenceType: String?
    let isRead: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case referenceId = "reference_id"
        case referenceType = "reference_type"
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}
