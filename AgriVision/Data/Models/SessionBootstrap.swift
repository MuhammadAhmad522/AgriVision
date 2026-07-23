import Foundation

struct SessionBootstrap: Decodable {
    let user: BackendUser
    let fields: [Field]
    let activeFieldLimit: Int
    let activeFieldCount: Int

    enum CodingKeys: String, CodingKey {
        case user, fields
        case activeFieldLimit = "active_field_limit"
        case activeFieldCount = "active_field_count"
    }
}

struct BackendUser: Decodable {
    let id: UUID
    let firebaseUid: String
    let email: String?

    enum CodingKeys: String, CodingKey {
        case id, email
        case firebaseUid = "firebase_uid"
    }
}
