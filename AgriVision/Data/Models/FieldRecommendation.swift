import Foundation

/// Represents a single AI-generated agronomic recommendation.
/// Populated by the backend's Gemini-powered AI Advisor Worker.
struct FieldRecommendation: Codable, Identifiable {
    let id: UUID
    let fieldId: UUID
    let category: String
    let priority: String       // "low", "medium", "high"
    let advice: String
    var rationale: String? = nil
    let confidence: Double?
    var confidenceReason: String? = nil
    var evidence: [RecommendationEvidence]? = nil
    var safetyLevel: String = "guarded"
    var requiresExpertConfirmation: Bool = false
    let status: String       // "pending", "implemented", "ignored"
    let ndviAtGeneration: Double?
    let createdAt: Date
    var expiresAt: Date? = nil
    var outcome: String? = nil
    var outcomeNotes: String? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case fieldId = "field_id"
        case category
        case priority
        case advice
        case rationale
        case confidence
        case confidenceReason = "confidence_reason"
        case evidence
        case safetyLevel = "safety_level"
        case requiresExpertConfirmation = "requires_expert_confirmation"
        case status
        case ndviAtGeneration = "ndvi_at_generation"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case outcome
        case outcomeNotes = "outcome_notes"
    }

    /// Maps the backend category string to a display emoji icon.
    var icon: String {
        switch category {
        case "Irrigation":        return "💧"
        case "Plant Health":      return "🌿"
        case "Weather Alert":     return "⛈️"
        case "Fertilizer Window": return "🌱"
        case "Harvest Timing":    return "🌾"
        case "Pest Risk":         return "🐛"
        default:                  return "🔬"
        }
    }

    /// Maps the priority string to a SwiftUI-friendly Color name.
    var priorityColor: String {
        switch priority {
        case "high":   return "red"
        case "medium": return "orange"
        default:       return "teal"
        }
    }

    /// Human-readable confidence percentage.
    var confidencePercent: String {
        guard let c = confidence else { return "N/A" }
        return "\(Int(c * 100))%"
    }
}

struct RecommendationEvidence: Codable, Identifiable {
    var id: String { url }
    let url: String
    let approved: Bool?
}
