import SwiftUI

/// Explains the AI-computed field health score: the score/label the farmer sees on the
/// dashboard card, the AI's own plain-language rationale, and the recommendation/advisor
/// context behind it. Deliberately does not invent a per-factor weight breakdown — the AI
/// only produces a score, a label, and a rationale, and showing anything more precise than
/// that would fabricate a level of detail the model never actually reasoned about.
struct AIFieldHealthDetailView: View {
    var healthScore: Double?
    var healthLabel: String
    var rationale: String?
    var updatedAt: Date?
    var cropType: String
    var recommendations: [FieldRecommendation]
    var advisorStatus: String

    private var labelInfo: (title: String, color: Color) {
        switch healthLabel {
        case "excellent": return ("Excellent", Theme.Colors.primaryMedium)
        case "good": return ("Good", .green)
        case "needs_attention": return ("Needs Attention", .orange)
        case "at_risk": return ("At Risk", .red)
        default: return ("Not Enough Data Yet", .secondary)
        }
    }

    private var updatedAtText: String {
        guard let updatedAt else { return "Not yet assessed" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Updated \(formatter.localizedString(for: updatedAt, relativeTo: Date()))"
    }

    private var openRecommendations: [FieldRecommendation] {
        recommendations.filter { $0.status == "pending" }
    }

    private var highPriorityCount: Int {
        openRecommendations.filter { $0.priority == "high" }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero Score Card
                VStack(spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AI Field Health")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(healthScore.map { "\(Int($0))%" } ?? "--")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.Colors.primary)
                        }
                        Spacer()

                        Text(labelInfo.title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(labelInfo.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(labelInfo.color.opacity(0.14), in: Capsule())
                            .multilineTextAlignment(.trailing)
                    }

                    Text(updatedAtText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)

                // AI Rationale
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(Theme.Colors.primaryMedium)
                        Text("Why this score, for \(cropType)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.Colors.primary)
                    }

                    Text(rationale?.isEmpty == false ? rationale! : "The AI advisor hasn't produced an assessment for this field yet. Check back after the next analysis run.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.primaryMedium.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Theme.Colors.primaryMedium.opacity(0.2), lineWidth: 1)
                )

                // Supporting Context
                VStack(alignment: .leading, spacing: 14) {
                    Text("What Fed This Assessment")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.Colors.primary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        statTile("Open Recommendations", "\(openRecommendations.count)")
                        statTile("High Priority", "\(highPriorityCount)")
                    }

                    if advisorStatus == "stale" || advisorStatus == "unavailable" {
                        Text("The AI advisor couldn't complete its most recent analysis — this reflects the last successful assessment.")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                }
                .padding(20)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
            }
            .padding(20)
        }
    }

    private func statTile(_ label: String, _ val: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 11)).foregroundColor(.secondary)
            Text(val).font(.system(size: 16, weight: .bold)).foregroundColor(Theme.Colors.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.02), in: RoundedRectangle(cornerRadius: 12))
    }
}
