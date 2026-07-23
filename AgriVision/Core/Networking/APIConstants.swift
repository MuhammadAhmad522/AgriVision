import Foundation

struct APIConstants {
    /// Simulator/local-Mac default. A physical device must use the Mac's LAN address.
    static let baseURL = URL(string: "http://localhost:8000")!

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
