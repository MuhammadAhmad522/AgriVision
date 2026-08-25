import SwiftUI

// MARK: - AI Advisor Section Card

/// The full AI Advisor section shown on the Dashboard.
/// Displays a list of AI-generated recommendations with premium animations.
struct AIAdvisorCard: View {
    let recommendations: [FieldRecommendation]
    let isLoading: Bool

    var body: some View {
        GlassCard(title: "🤖 AI Field Advisor") {
            if isLoading {
                // Shimmer placeholder while loading
                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        ShimmerRow()
                    }
                }
            } else if recommendations.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "brain.head.profile")
                        .textStyle(.title1)
                        .foregroundColor(Theme.Colors.primaryMedium.opacity(0.5))
                    Text("AI is analyzing your field data…")
                        .textStyle(.body)
                        .foregroundColor(Theme.Colors.primary.opacity(0.5))
                    Text("Recommendations will appear after the next satellite sync.")
                        .textStyle(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Theme.Colors.primary.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(recommendations.enumerated()), id: \.element.id) { index, rec in
                        RecommendationRow(recommendation: rec)
                        if index < recommendations.count - 1 {
                            Divider()
                                .background(Theme.Colors.primaryLight.opacity(0.2))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Individual Recommendation Row

private struct RecommendationRow: View {
    let recommendation: FieldRecommendation
    @State private var isExpanded = false

    var priorityColor: Color {
        switch recommendation.priority {
        case "high":   return Color.red
        case "medium": return Color.orange
        default:       return Color.teal
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left priority border bar
            RoundedRectangle(cornerRadius: 2)
                .fill(priorityColor)
                .frame(width: 4)
                .padding(.vertical, 2)
                .padding(.trailing, 10)

            VStack(alignment: .leading, spacing: 8) {
                // Header row: icon, category, priority badge
                HStack(alignment: .center, spacing: 10) {
                    // Icon circle
                    ZStack {
                        Circle()
                            .fill(priorityColor.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Text(recommendation.icon)
                            .textStyle(.body)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(recommendation.category)
                            .textStyle(.bodyStrong)
                            .foregroundColor(Theme.Colors.primary)

                        // Confidence bar
                        if let confidence = recommendation.confidence {
                            HStack(spacing: 4) {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.gray.opacity(0.15))
                                        Capsule()
                                            .fill(LinearGradient(
                                                colors: [priorityColor.opacity(0.6), priorityColor],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ))
                                            .frame(width: geo.size.width * confidence)
                                    }
                                }
                                .frame(height: 4)

                                Text("\(Int(confidence * 100))%")
                                    .font(.caption2.bold())
                                    .foregroundColor(priorityColor)
                                    .frame(width: 32, alignment: .trailing)
                            }
                        }
                    }

                    Spacer()

                    // Priority badge
                    Text(recommendation.priority.uppercased())
                        .textStyle(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(priorityColor.opacity(0.15))
                        .foregroundColor(priorityColor)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(priorityColor.opacity(0.3), lineWidth: 0.5))
                }

                // Advice text — expandable
                Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { isExpanded.toggle() } }) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 6) {
                            Text(recommendation.advice)
                                .textStyle(.body)
                                .foregroundColor(Theme.Colors.primary.opacity(0.85))
                                .lineLimit(isExpanded ? nil : 3)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .textStyle(.captionStrong)
                                .foregroundColor(Theme.Colors.primaryLight)
                        }

                        if recommendation.requiresExpertConfirmation {
                            HStack(spacing: 4) {
                                Image(systemName: recommendation.expertStatus == "approved" ? "checkmark.seal.fill" : (recommendation.expertStatus == "rejected" ? "xmark.seal.fill" : "person.badge.shield.checkmark"))
                                    .textStyle(.caption)
                                Text(recommendation.expertStatus == "approved" ? "Expert Approved" : (recommendation.expertStatus == "rejected" ? "Expert Rejected" : "Pending Expert Review"))
                                    .font(.caption2.bold())
                            }
                            .foregroundColor(recommendation.expertStatus == "approved" ? .green : (recommendation.expertStatus == "rejected" ? .red : .orange))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((recommendation.expertStatus == "approved" ? Color.green : (recommendation.expertStatus == "rejected" ? Color.red : Color.orange)).opacity(0.1))
                            .cornerRadius(4)
                        }
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 6) {
                        if let rationale = recommendation.rationale, !rationale.isEmpty {
                            Text("Rationale:")
                                .font(.caption2.bold())
                                .foregroundColor(Theme.Colors.primary.opacity(0.6))
                            Text(rationale)
                                .textStyle(.caption)
                                .foregroundColor(Theme.Colors.primary.opacity(0.7))
                        }
                        if let reason = recommendation.confidenceReason, !reason.isEmpty {
                            Text("Evidence Basis: \(reason)")
                                .font(.caption2.italic())
                                .foregroundColor(.secondary)
                        }
                        if let notes = recommendation.expertNotes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption2)
                                        .foregroundColor(Theme.Colors.primaryLight)
                                    Text("Expert Note")
                                        .font(.caption2.bold())
                                        .foregroundColor(Theme.Colors.primary)
                                }
                                Text(notes)
                                    .textStyle(.caption)
                                    .foregroundColor(Theme.Colors.primary.opacity(0.8))
                            }
                            .padding(6)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.Colors.primary.opacity(0.2), lineWidth: 1))
                            .padding(.top, 4)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Shimmer Placeholder

private struct ShimmerRow: View {
    @State private var phase: CGFloat = -1.0

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 38, height: 38)
                .shimmer(phase: phase)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 12)
                    .frame(maxWidth: .infinity)
                    .shimmer(phase: phase)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 10)
                    .frame(maxWidth: 200)
                    .shimmer(phase: phase)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                phase = 1.0
            }
        }
    }
}

// MARK: - Shimmer Modifier

private extension View {
    func shimmer(phase: CGFloat) -> some View {
        self.overlay(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: phase - 0.3),
                    .init(color: Color.white.opacity(0.4), location: phase),
                    .init(color: .clear, location: phase + 0.3),
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .blendMode(.plusLighter)
        )
        .clipped()
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.edgesIgnoringSafeArea(.all)
        
        AIAdvisorCard(recommendations: [
            FieldRecommendation(
                id: UUID(), fieldId: UUID(), category: "Irrigation", priority: "high",
                advice: "Soil moisture is critically low at 0.19 m³/m³. Irrigate within the next 12 hours.",
                confidence: 0.91, status: "pending", ndviAtGeneration: 0.23, createdAt: Date()
            ),
            FieldRecommendation(
                id: UUID(), fieldId: UUID(), category: "Weather Alert", priority: "medium",
                advice: "Heavy rain of 14mm is forecast in 48 hours. Postpone fertilizer application.",
                confidence: 0.75, status: "pending", ndviAtGeneration: 0.23, createdAt: Date()
            ),
            FieldRecommendation(
                id: UUID(), fieldId: UUID(), category: "Plant Health", priority: "low",
                advice: "NDVI is stable at 0.23. Continue monitoring.",
                confidence: 0.80, status: "pending", ndviAtGeneration: 0.23, createdAt: Date()
            )
        ], isLoading: false)
        .padding()
    }
}
