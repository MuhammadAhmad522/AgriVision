import Foundation

/// Severity as set by the agronomist who sent the advisory.
enum NotificationPriority: String, Codable {
    case low, normal, high, urgent

    /// Decoded leniently: an unknown value from a newer backend must not fail the whole
    /// inbox decode and leave the farmer with no notifications at all.
    init(rawValue: String) {
        switch rawValue.lowercased() {
        case "low": self = .low
        case "high": self = .high
        case "urgent": self = .urgent
        default: self = .normal
        }
    }
}

struct UserNotification: Codable, Identifiable {
    let id: UUID
    let title: String
    let body: String
    let referenceId: String?
    let referenceType: String?
    let isRead: Bool
    let createdAt: Date

    /// Which field the advice concerns. A farmer with several fields cannot act on a
    /// message that does not say where.
    let fieldId: UUID?
    let fieldName: String?
    /// Who sent it. Expert advice that can gate a chemical intervention is attributable.
    let createdByEmail: String?
    let priority: NotificationPriority
    let category: String?

    /// True when this came from a person rather than the automatic system.
    var isFromExpert: Bool {
        createdByEmail != nil && (
            category == "expert_advisory" ||
            category == "expert_review" ||
            category == "guidance_update"
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case referenceId = "reference_id"
        case referenceType = "reference_type"
        case isRead = "is_read"
        case createdAt = "created_at"
        case fieldId = "field_id"
        case fieldName = "field_name"
        case createdByEmail = "created_by_email"
        case priority
        case category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        referenceId = try container.decodeIfPresent(String.self, forKey: .referenceId)
        referenceType = try container.decodeIfPresent(String.self, forKey: .referenceType)
        isRead = try container.decode(Bool.self, forKey: .isRead)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        // Optional so a notification stored before these columns existed still decodes.
        fieldId = try container.decodeIfPresent(UUID.self, forKey: .fieldId)
        fieldName = try container.decodeIfPresent(String.self, forKey: .fieldName)
        createdByEmail = try container.decodeIfPresent(String.self, forKey: .createdByEmail)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        let rawPriority = try container.decodeIfPresent(String.self, forKey: .priority) ?? "normal"
        priority = NotificationPriority(rawValue: rawPriority)
    }

    init(
        id: UUID,
        title: String,
        body: String,
        referenceId: String?,
        referenceType: String?,
        isRead: Bool,
        createdAt: Date,
        fieldId: UUID? = nil,
        fieldName: String? = nil,
        createdByEmail: String? = nil,
        priority: NotificationPriority = .normal,
        category: String? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.referenceId = referenceId
        self.referenceType = referenceType
        self.isRead = isRead
        self.createdAt = createdAt
        self.fieldId = fieldId
        self.fieldName = fieldName
        self.createdByEmail = createdByEmail
        self.priority = priority
        self.category = category
    }
}
