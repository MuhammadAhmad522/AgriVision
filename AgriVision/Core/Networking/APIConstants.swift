import Foundation

/**
 `APIConstants` centralizes network configuration.
 Using a struct instead of hardcoded strings in repositories ensures that changes 
 to the backend URL only need to be updated in one place (DRY principle).
 */
struct APIConstants {
    /// The base URL for our FastAPI backend.
    /// - Note: If testing on a physical device, replace 'localhost' with your Mac's local IP.
    static let baseURL = URL(string: "http://34.67.93.107:8000")!
    
    /// API Endpoints
    struct Endpoints {
        static let fields = "api/fields/"
        static let sensors = "api/sensors/"
        static let readings = "api/sensors/readings/"
        static func verifySensor(deviceId: String) -> String {
            "api/sensors/verify/\(deviceId)"
        }
        
        static func recommendations(for fieldId: UUID) -> String {
            "api/fields/\(fieldId.uuidString.lowercased())/recommendations/"
        }
        
        static func feedback(for fieldId: UUID, recommendationId: UUID) -> String {
            "api/fields/\(fieldId.uuidString.lowercased())/recommendations/\(recommendationId.uuidString.lowercased())/feedback"
        }
        
        static func chat(for fieldId: UUID) -> String {
            "fields/\(fieldId.uuidString.lowercased())/chat"
        }
    }
}
