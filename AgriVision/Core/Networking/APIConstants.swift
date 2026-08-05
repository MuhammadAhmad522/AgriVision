import Foundation

struct APIConstants {
    /// Base URL for backend services. Defaults to localhost:8000 for iOS Simulator,
    /// or reads from UserDefaults key "agrivision_backend_url" for physical device testing.
    static var baseURL: URL {
        if let customURLString = UserDefaults.standard.string(forKey: "agrivision_backend_url"),
           let url = URL(string: customURLString) {
            return url
        }
        return URL(string: "http://localhost:8000")!
    }

    struct Endpoints {
        static let bootstrap = "api/session/bootstrap"
        static let fields = "api/fields"

        static func field(_ id: UUID) -> String { "api/fields/\(id.uuidString.lowercased())" }
        static func dataRefresh(_ id: UUID) -> String { "\(field(id))/data-refresh" }
        static func dashboard(_ id: UUID) -> String { "\(field(id))/dashboard" }
        static func readings(_ id: UUID) -> String { "\(field(id))/sensor-readings" }
        static func assignSensor(to id: UUID) -> String { "\(field(id))/sensors" }
        static func recommendations(for id: UUID) -> String { "\(field(id))/recommendations" }
        static func feedback(_ recommendationID: UUID) -> String { "api/recommendations/\(recommendationID.uuidString.lowercased())/feedback" }
        static func outcome(_ recommendationID: UUID) -> String { "api/recommendations/\(recommendationID.uuidString.lowercased())/outcome" }
        static func chat(for id: UUID) -> String { "\(field(id))/chat" }
        static func chatAttachment(fieldId: UUID, attachmentId: UUID) -> String { "\(chat(for: fieldId))/attachments/\(attachmentId.uuidString.lowercased())" }
        static func verifySensor(deviceId: String) -> String {
            let safe = deviceId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
            return "api/sensors/verify/\(safe)"
        }
        static let pairSensor = "api/sensors/pair"
    }
}
