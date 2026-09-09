import SwiftUI

// MARK: - Priority Styling

/// Visual treatment derived from a recommendation's priority. Kept in one place so the
/// advisor sheet and the dashboard advisor card can never drift apart.
struct RecommendationPriorityStyle {
    let color: Color
    let label: String
    let icon: String

    init(priority: String) {
        switch priority {
        case "high":
            color = Color(red: 0.84, green: 0.26, blue: 0.22)
            label = "High"
            icon = "exclamationmark.triangle.fill"
        case "medium":
            color = Color(red: 0.90, green: 0.56, blue: 0.13)
            label = "Medium"
            icon = "clock.fill"
        default:
            color = Theme.Colors.primaryMedium
            label = "Low"
            icon = "leaf.fill"
        }
    }
}

private func recommendationHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    #if os(iOS)
    UIImpactFeedbackGenerator(style: style).impactOccurred()
    #endif
}

// MARK: - Action Bar

/// The one decision a farmer makes on a recommendation, made deliberately loud: a filled,
/// full-width "Mark implemented" paired with a quieter "Dismiss", both on a 48pt tap target.
struct RecommendationActionBar: View {
    /// Non-nil while a feedback call is in flight — carries the status being written.
    var pendingStatus: String? = nil
    var onFeedback: (String) -> Void

    private var isBusy: Bool { pendingStatus != nil }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                recommendationHaptic(.medium)
                onFeedback("implemented")
            } label: {
                HStack(spacing: 7) {
                    if pendingStatus == "implemented" {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text("Mark implemented")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    LinearGradient(
                        colors: [Theme.Colors.primaryMedium, Theme.Colors.primary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .shadow(color: Theme.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .accessibilityLabel("Mark this recommendation as implemented")

            Button {
                recommendationHaptic(.light)
                onFeedback("ignored")
            } label: {
                HStack(spacing: 6) {
                    if pendingStatus == "ignored" {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Theme.Colors.textSecondary)
                    } else {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text("Dismiss")
                        .lineLimit(1)
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.Colors.textSecondary)
                .frame(width: 108)
                .frame(height: 48)
                .background(
                    Theme.Colors.surfaceHighlight,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.Colors.textSecondary.opacity(0.25), lineWidth: 1)
                )
            }
            .accessibilityLabel("Dismiss this recommendation")
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .opacity(isBusy ? 0.75 : 1)
        .animation(.easeInOut(duration: 0.2), value: pendingStatus)
    }
}

// MARK: - Outcome Bar

/// Follow-up shown after advice is implemented. Three equal chips beat a hidden menu —
/// the farmer can see every answer without discovering a tap target first.
struct RecommendationOutcomeBar: View {
    var pendingOutcome: String? = nil
    var onOutcome: (String) -> Void

    private struct Option {
        let value: String
        let title: String
        let icon: String
        let color: Color
    }

    private var options: [Option] {
        [
            Option(value: "useful", title: "Worked", icon: "hand.thumbsup.fill", color: Theme.Colors.primaryMedium),
            Option(value: "ineffective", title: "No change", icon: "equal.circle.fill", color: .orange),
            Option(value: "harmful", title: "Made it worse", icon: "hand.thumbsdown.fill", color: .red)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How did it work out?")
                .textStyle(.captionStrong)

            HStack(spacing: 8) {
                ForEach(options, id: \.value) { option in
                    Button {
                        recommendationHaptic(.light)
                        onOutcome(option.value)
                    } label: {
                        VStack(spacing: 5) {
                            if pendingOutcome == option.value {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(option.color)
                                    .frame(height: 17)
                            } else {
                                Image(systemName: option.icon)
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(height: 17)
                            }
                            Text(option.title)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .foregroundColor(option.color)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            option.color.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(option.color.opacity(0.28), lineWidth: 1)
                        )
                    }
                    .accessibilityLabel("Record outcome: \(option.title)")
                }
            }
            .buttonStyle(.plain)
            .disabled(pendingOutcome != nil)
            .opacity(pendingOutcome != nil ? 0.75 : 1)
        }
    }
}

// MARK: - Resolved State Banner

/// Replaces the action bar once a recommendation has been answered, so a resolved card
/// still reads as resolved at a glance instead of just losing its buttons.
struct RecommendationStatusBanner: View {
    let status: String
    var outcome: String? = nil

    private var isImplemented: Bool { status == "implemented" }

    private var tint: Color {
        isImplemented ? Theme.Colors.primaryMedium : Theme.Colors.textSecondary
    }

    private var title: String {
        isImplemented ? "Implemented" : "Dismissed"
    }

    private var outcomeLabel: String? {
        switch outcome {
        case "useful":       return "Worked"
        case "ineffective":  return "No change"
        case "harmful":      return "Made it worse"
        default:             return nil
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isImplemented ? "checkmark.seal.fill" : "archivebox.fill")
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            if let outcomeLabel {
                Text("·")
                    .foregroundColor(tint.opacity(0.5))
                Text(outcomeLabel)
                    .font(.system(size: 14, weight: .regular))
            }
            Spacer()
        }
        .foregroundColor(outcome == "harmful" ? .red : tint)
        .padding(.horizontal, 12)
        .frame(height: 40)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (outcome == "harmful" ? Color.red : tint).opacity(0.1),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

// MARK: - Confidence Meter

private struct ConfidenceMeter: View {
    let confidence: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Text("Confidence")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.Colors.textSecondary.opacity(0.8))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Colors.textSecondary.opacity(0.15))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [tint.opacity(0.55), tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: max(6, geo.size.width * min(max(confidence, 0), 1)))
                }
            }
            .frame(height: 6)

            Text("\(Int(confidence * 100))%")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 34, alignment: .trailing)
        }
    }
}

// MARK: - Expert Badge

private struct ExpertReviewBadge: View {
    let expertStatus: String

    private var tint: Color {
        switch expertStatus {
        case "approved": return Theme.Colors.primaryMedium
        case "rejected": return .red
        default:         return .orange
        }
    }

    private var icon: String {
        switch expertStatus {
        case "approved": return "checkmark.seal.fill"
        case "rejected": return "xmark.seal.fill"
        default:         return "person.badge.shield.checkmark"
        }
    }

    private var title: String {
        switch expertStatus {
        case "approved": return "Verified by agronomist"
        case "rejected": return "Rejected by agronomist"
        default:         return "Awaiting agronomist review"
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

// MARK: - Recommendation Card

/// A single AI recommendation, presented as a self-contained card: priority is readable at a
/// glance from the accent stripe and pill, the advice leads, and the accept/dismiss decision
/// sits in a full-width action bar at the bottom where it cannot be missed.
struct RecommendationCard: View {
    let recommendation: FieldRecommendation
    var onFeedback: (String) async -> Void
    var onOutcome: (String) async -> Void

    @State private var isExpanded = false
    @State private var pendingStatus: String?
    @State private var pendingOutcome: String?

    private var style: RecommendationPriorityStyle {
        RecommendationPriorityStyle(priority: recommendation.priority)
    }

    private var isResolved: Bool { recommendation.status != "pending" }

    /// Advice blocked behind an unfinished expert review must not offer an action yet.
    private var isAwaitingExpert: Bool {
        recommendation.requiresExpertConfirmation && recommendation.expertStatus == "pending"
    }

    private var hasDetails: Bool {
        let rationale = recommendation.rationale?.isEmpty == false
        let reason = recommendation.confidenceReason?.isEmpty == false
        let notes = recommendation.expertNotes?.isEmpty == false
        let evidence = !(recommendation.evidence ?? []).isEmpty
        return rationale || reason || notes || evidence
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            advice
            if let confidence = recommendation.confidence {
                ConfidenceMeter(confidence: confidence, tint: style.color)
            }
            if recommendation.requiresExpertConfirmation {
                ExpertReviewBadge(expertStatus: recommendation.expertStatus)
            }
            if hasDetails {
                detailsDisclosure
            }
            actionArea
        }
        .padding(16)
        .padding(.leading, 5) // clears the accent stripe
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface)
        .overlay(alignment: .leading) {
            LinearGradient(
                colors: [style.color, style.color.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.Colors.textSecondary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.07), radius: 10, x: 0, y: 4)
        .opacity(isResolved ? 0.82 : 1)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(style.color.opacity(0.14))
                    .frame(width: 46, height: 46)
                Text(recommendation.icon)
                    .font(.system(size: 22))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(recommendation.category)
                    .textStyle(.bodyStrong)

                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: style.icon)
                            .font(.system(size: 9, weight: .bold))
                        Text(style.label.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.4)
                    }
                    .foregroundColor(style.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(style.color.opacity(0.14), in: Capsule())

                    Text(recommendation.relativeCreatedAt)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textSecondary.opacity(0.8))
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: Advice

    private var advice: some View {
        Text(recommendation.advice)
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(Theme.Colors.textPrimary.opacity(0.9))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Details

    private var detailsDisclosure: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Text(isExpanded ? "Hide details" : "Why this advice?")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .foregroundColor(Theme.Colors.primaryMedium)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    if let rationale = recommendation.rationale, !rationale.isEmpty {
                        detailBlock(title: "Rationale", body: rationale)
                    }
                    if let reason = recommendation.confidenceReason, !reason.isEmpty {
                        detailBlock(title: "Evidence basis", body: reason)
                    }
                    if let notes = recommendation.expertNotes, !notes.isEmpty {
                        detailBlock(title: "Expert note", body: notes)
                    }
                    let sources = (recommendation.evidence ?? []).compactMap { source -> (String, URL)? in
                        guard let urlString = source.url, let url = URL(string: urlString) else { return nil }
                        return (urlString, url)
                    }
                    if !sources.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sources")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.Colors.textSecondary.opacity(0.8))
                            ForEach(sources, id: \.0) { urlString, url in
                                Link(destination: url) {
                                    Text(urlString)
                                        .font(.system(size: 12))
                                        .underline()
                                        .lineLimit(1)
                                        .foregroundColor(Theme.Colors.primaryMedium)
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Theme.Colors.surfaceHighlight.opacity(0.7),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func detailBlock(title: String, body text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.Colors.textSecondary.opacity(0.8))
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.textPrimary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Actions

    @ViewBuilder
    private var actionArea: some View {
        if !isResolved {
            if isAwaitingExpert {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Actions unlock once an agronomist reviews this advice.")
                        .font(.system(size: 12))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundColor(.orange)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                RecommendationActionBar(pendingStatus: pendingStatus) { status in
                    guard pendingStatus == nil else { return }
                    Task {
                        pendingStatus = status
                        await onFeedback(status)
                        pendingStatus = nil
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                RecommendationStatusBanner(status: recommendation.status, outcome: recommendation.outcome)
                if recommendation.status == "implemented" && recommendation.outcome == nil {
                    RecommendationOutcomeBar(pendingOutcome: pendingOutcome) { outcome in
                        guard pendingOutcome == nil else { return }
                        Task {
                            pendingOutcome = outcome
                            await onOutcome(outcome)
                            pendingOutcome = nil
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 14) {
            RecommendationCard(
                recommendation: FieldRecommendation(
                    id: UUID(), fieldId: UUID(), category: "Irrigation", priority: "high",
                    advice: "Soil moisture is critically low at 0.19 m³/m³. Irrigate within the next 12 hours to avoid stress on the flowering stage.",
                    rationale: "Moisture has fallen for four consecutive readings while NDVI dipped 0.04.",
                    confidence: 0.91, status: "pending", ndviAtGeneration: 0.23, createdAt: Date().addingTimeInterval(-7200)
                ),
                onFeedback: { _ in }, onOutcome: { _ in }
            )
            RecommendationCard(
                recommendation: FieldRecommendation(
                    id: UUID(), fieldId: UUID(), category: "Weather Alert", priority: "medium",
                    advice: "Heavy rain of 14mm is forecast in 48 hours. Postpone fertilizer application.",
                    confidence: 0.75, status: "implemented", ndviAtGeneration: 0.23, createdAt: Date().addingTimeInterval(-86400)
                ),
                onFeedback: { _ in }, onOutcome: { _ in }
            )
            RecommendationCard(
                recommendation: FieldRecommendation(
                    id: UUID(), fieldId: UUID(), category: "Plant Health", priority: "low",
                    advice: "NDVI is stable at 0.23. Continue monitoring.",
                    confidence: 0.80, status: "ignored", ndviAtGeneration: 0.23, createdAt: Date().addingTimeInterval(-172800)
                ),
                onFeedback: { _ in }, onOutcome: { _ in }
            )
        }
        .padding(16)
    }
    .background(Theme.Colors.background)
}
