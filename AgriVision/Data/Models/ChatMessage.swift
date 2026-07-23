import Foundation

struct ChatAttachment: Codable, Identifiable {
    let id: UUID
    let mimeType: String
    let byteSize: Int
    let width: Int
    let height: Int
    let url: String

    enum CodingKeys: String, CodingKey {
        case id, width, height, url
        case mimeType = "mime_type"
        case byteSize = "byte_size"
    }
}

struct ChatMessage: Codable, Identifiable {
    let id: UUID
    let role: String
    let content: String
    let status: String
    let attachments: [ChatAttachment]
    let createdAt: Date

    init(id: UUID, role: String, content: String, status: String = "completed", attachments: [ChatAttachment] = [], createdAt: Date) {
        self.id = id
        self.role = role
        self.content = content
        self.status = status
        self.attachments = attachments
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, role, content, status, attachments
        case createdAt = "created_at"
    }
}

struct ChatTurn: Codable {
    let userMessage: ChatMessage
    let assistantMessage: ChatMessage

    enum CodingKeys: String, CodingKey {
        case userMessage = "user_message"
        case assistantMessage = "assistant_message"
    }
}

struct ChatImageUpload: Identifiable {
    let id: UUID
    let data: Data
    let filename: String
    let mimeType: String

    init(id: UUID = UUID(), data: Data, filename: String = "field-photo.jpg", mimeType: String = "image/jpeg") {
        self.id = id
        self.data = data
        self.filename = filename
        self.mimeType = mimeType
    }
}
