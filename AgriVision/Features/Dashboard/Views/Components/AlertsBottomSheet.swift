import SwiftUI

struct AlertsBottomSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    var onAskAI: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                AdvisorSummaryPanel(
                    title: viewModel.activeField?.name ?? "Selected field",
                    subtitle: advisorSummary,
                    isRefreshing: viewModel.isRefreshingAI,
                    onRefresh: { Task { await viewModel.refreshRecommendations() } },
                    onAskAI: {
                        if let onAskAI { onAskAI() } else { viewModel.openChat() }
                    }
                )

                if viewModel.recommendations.isEmpty {
                    AdvisorEmptyPanel(
                        isLoading: viewModel.isLoading,
                        status: viewModel.advisorStatus,
                        message: viewModel.advisorMessage,
                        dataQuality: viewModel.advisorDataQuality,
                        onRetry: { Task { await viewModel.refreshRecommendations() } }
                    )
                } else {
                    if viewModel.advisorStatus == "stale" || viewModel.advisorStatus == "unavailable" {
                        AdvisorStaleStrip(
                            message: viewModel.advisorMessage ?? "Showing the last successful advice while AI retries.",
                            onRetry: { Task { await viewModel.refreshRecommendations() } }
                        )
                    }

                    ForEach(sortedRecommendations) { recommendation in
                        RecommendationCard(
                            recommendation: recommendation,
                            onFeedback: { status in
                                await viewModel.updateFeedback(recommendation, status: status)
                            },
                            onOutcome: { outcome in
                                await viewModel.recordOutcome(recommendation, outcome: outcome)
                            }
                        )
                    }
                }

                if let narrative = viewModel.seasonMemory?.narrative, !narrative.isEmpty {
                    CropJournalPanel(narrative: narrative, events: viewModel.seasonMemory?.keyEvents ?? [])
                }

                // Extra space so the last card can scroll clear of the floating tab bar.
                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: viewModel.recommendations)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        // The dashboard's own toast overlay sits behind this sheet, so a refresh started here
        // would otherwise report its result to a screen the farmer cannot see.
        .overlay(alignment: .top) {
            if let error = viewModel.errorMessage {
                ToastView(message: error, type: .error)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if let success = viewModel.successMessage {
                ToastView(message: success, type: .success)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.successMessage)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.errorMessage)
    }

    /// Unanswered advice first, then most urgent — the sheet is a to-do list, so anything
    /// still needing a decision belongs at the top.
    private var sortedRecommendations: [FieldRecommendation] {
        func priorityRank(_ priority: String) -> Int {
            switch priority {
            case "high":   return 0
            case "medium": return 1
            default:       return 2
            }
        }
        return viewModel.recommendations.enumerated().sorted { lhs, rhs in
            let lhsPending = lhs.element.status == "pending"
            let rhsPending = rhs.element.status == "pending"
            if lhsPending != rhsPending { return lhsPending }
            let lhsRank = priorityRank(lhs.element.priority)
            let rhsRank = priorityRank(rhs.element.priority)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    private var advisorSummary: String {
        let count = viewModel.recommendations.count
        if count == 0 { return "Preparing recommendations" }
        let pending = viewModel.recommendations.filter { $0.status == "pending" }.count
        let total = "\(count) recommendation\(count == 1 ? "" : "s")"
        return pending == 0 ? "\(total) · all answered" : "\(total) · \(pending) awaiting your call"
    }
}

// MARK: - Summary Panel

private struct AdvisorSummaryPanel: View {
    let title: String
    let subtitle: String
    let isRefreshing: Bool
    let onRefresh: () -> Void
    let onAskAI: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.primaryMedium.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.Colors.primaryMedium)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .textStyle(.bodyStrong)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button(action: onRefresh) {
                    HStack(spacing: 6) {
                        if isRefreshing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Theme.Colors.textSecondary)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .bold))
                        }
                        Text("Refresh advice")
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        Theme.Colors.surfaceHighlight,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.Colors.textSecondary.opacity(0.25), lineWidth: 1)
                    )
                }
                .disabled(isRefreshing)

                Button(action: onAskAI) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.and.text.bubble.right.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Ask AI")
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        LinearGradient(
                            colors: [Theme.Colors.primaryMedium, Theme.Colors.primary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.Colors.textSecondary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Empty / Stale States

private struct AdvisorEmptyPanel: View {
    let isLoading: Bool
    let status: String
    let message: String?
    let dataQuality: String?
    let onRetry: () -> Void

    private var isError: Bool { status == "unavailable" || status == "stale" }

    var body: some View {
        VStack(spacing: 12) {
            if isLoading || status == "pending" {
                ProgressView()
                    .controlSize(.large)
                    .tint(Theme.Colors.primaryMedium)
            } else {
                Image(systemName: isError ? "exclamationmark.triangle.fill" : "brain.head.profile")
                    .font(.system(size: 34, weight: .light))
                    .foregroundColor(isError ? .orange : Theme.Colors.primaryMedium.opacity(0.6))
            }

            Text(
                isLoading
                    ? "Loading recommendations…"
                    : (message ?? "AI is preparing the first field assessment.")
            )
            .font(.system(size: 15))
            .multilineTextAlignment(.center)
            .foregroundColor(Theme.Colors.textPrimary.opacity(0.85))

            if let dataQuality {
                Text("Evidence quality: \(dataQuality.capitalized)")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            if isError {
                Button(action: onRetry) {
                    Text("Retry analysis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 42)
                        .background(
                            LinearGradient(
                                colors: [Theme.Colors.primaryMedium, Theme.Colors.primary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.Colors.textSecondary.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct AdvisorStaleStrip: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.system(size: 13, weight: .semibold))
            Text(message)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Retry", action: onRetry)
                .font(.system(size: 13, weight: .semibold))
                .buttonStyle(.plain)
        }
        .foregroundColor(.orange)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Crop Journal

private struct CropJournalPanel: View {
    let narrative: String
    let events: [SeasonKeyEvent]

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "book.pages")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.Colors.primaryMedium)
                    Text("Crop Journal")
                        .textStyle(.bodyStrong)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(narrative)
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Colors.textPrimary.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(events) { event in
                        if let description = event.description {
                            HStack(alignment: .top, spacing: 7) {
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.Colors.primaryMedium)
                                    .padding(.top, 3)
                                Text(description)
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.Colors.textSecondary.opacity(0.12), lineWidth: 1)
        )
    }
}
