import SwiftUI

struct AlertsBottomSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    var onAskAI: (() -> Void)? = nil
    
    var body: some View {
        List {
            Section {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Field Advisor")
                            .textStyle(.bodyStrong)
                        Text(advisorSummary)
                            .textStyle(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                HStack {
                    Button { Task { await viewModel.refreshRecommendations() } } label: {
                        Label("Refresh advice", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isRefreshingAI)
                    Spacer()
                    Button(action: {
                        if let onAskAI {
                            onAskAI()
                        } else {
                            viewModel.openChat()
                        }
                    }) {
                        Label("Ask AI", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderless)
                if viewModel.recommendations.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            if viewModel.advisorStatus == "pending" {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }
                            Text(
                                viewModel.isLoading
                                    ? "Loading recommendations…"
                                    : (viewModel.advisorMessage ?? "AI is preparing the first field assessment.")
                            )
                        }
                        .foregroundStyle(.secondary)
                        if let quality = viewModel.advisorDataQuality {
                            Text("Evidence quality: \(quality.capitalized)")
                                .textStyle(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if viewModel.advisorStatus == "unavailable" || viewModel.advisorStatus == "stale" {
                            Button("Retry analysis") {
                                Task { await viewModel.refreshRecommendations() }
                            }
                            .textStyle(.captionStrong)
                        }
                    }
                } else {
                    if viewModel.advisorStatus == "stale" || viewModel.advisorStatus == "unavailable" {
                        Label(
                            viewModel.advisorMessage ?? "Showing the last successful advice while AI retries.",
                            systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90"
                        )
                        .textStyle(.caption)
                        .foregroundStyle(.orange)
                    }
                    if viewModel.recommendations.count > 1 {
                        Text("Scroll down to read every recommendation for this field.")
                            .textStyle(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.recommendations) { recommendation in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(recommendation.icon)
                                Text(recommendation.category).textStyle(.bodyStrong)
                                Spacer()
                                if recommendation.status == "implemented" {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                } else if recommendation.status == "ignored" {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                                } else {
                                    Text(recommendation.priority.capitalized).textStyle(.caption).foregroundStyle(.secondary)
                                }
                            }
                            
                            if recommendation.status == "pending" {
                                Text(recommendation.advice).textStyle(.body)
                                Text(recommendation.relativeCreatedAt).textStyle(.caption).foregroundStyle(.secondary)
                                
                                if recommendation.requiresExpertConfirmation {
                                    if recommendation.expertStatus == "approved" {
                                        Label("Verified by Agronomist", systemImage: "checkmark.seal.fill")
                                            .textStyle(.captionStrong).foregroundStyle(.green)
                                        if let notes = recommendation.expertNotes {
                                            Text(notes)
                                                .textStyle(.caption)
                                                .foregroundStyle(.secondary)
                                                .padding(6)
                                                .background(Color.gray.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                    } else if recommendation.expertStatus == "rejected" {
                                        Label("Rejected by Agronomist", systemImage: "xmark.seal.fill")
                                            .textStyle(.captionStrong).foregroundStyle(.red)
                                        if let notes = recommendation.expertNotes {
                                            Text(notes)
                                                .textStyle(.caption)
                                                .foregroundStyle(.secondary)
                                                .padding(6)
                                                .background(Color.gray.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                    } else {
                                        Label("Expert confirmation required", systemImage: "person.badge.shield.checkmark")
                                            .textStyle(.captionStrong).foregroundStyle(.orange)
                                    }
                                }
                                
                                if !recommendation.requiresExpertConfirmation || recommendation.expertStatus != "pending" {
                                    HStack {
                                        Button("Implemented") { Task { await viewModel.updateFeedback(recommendation, status: "implemented") } }
                                        Button("Ignore", role: .destructive) { Task { await viewModel.updateFeedback(recommendation, status: "ignored") } }
                                    }
                                    .textStyle(.caption)
                                    .buttonStyle(.borderless)
                                }
                            } else {
                                if recommendation.status == "implemented" && recommendation.outcome == nil {
                                    Menu {
                                        Button("Useful") { Task { await viewModel.recordOutcome(recommendation, outcome: "useful") } }
                                        Button("Ineffective") { Task { await viewModel.recordOutcome(recommendation, outcome: "ineffective") } }
                                        Button("Harmful", role: .destructive) { Task { await viewModel.recordOutcome(recommendation, outcome: "harmful") } }
                                    } label: {
                                        Label("How did it work?", systemImage: "chart.line.text.clipboard")
                                            .textStyle(.caption)
                                    }
                                } else if let outcome = recommendation.outcome {
                                    Text("Outcome: \(outcome.capitalized)")
                                        .textStyle(.caption)
                                        .foregroundStyle(outcome == "harmful" ? .red : .secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .buttonStyle(.plain)
                    }
                }
            }
            .listRowBackground(Color.gray.opacity(0.16))

            if let narrative = viewModel.seasonMemory?.narrative, !narrative.isEmpty {
                Section {
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(narrative)
                                .textStyle(.body)
                            if let events = viewModel.seasonMemory?.keyEvents, !events.isEmpty {
                                ForEach(events) { event in
                                    if let description = event.description {
                                        Label(description, systemImage: "bookmark.fill")
                                            .textStyle(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    } label: {
                        Label("Crop Journal", systemImage: "book.pages")
                            .textStyle(.bodyStrong)
                    }
                }
                .listRowBackground(Color.gray.opacity(0.16))
            }

            // Extra space at bottom to scroll past the floating tab bar if fully expanded
            Spacer().frame(height: 100)
                .listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
    }

    private var advisorSummary: String {
        let fieldName = viewModel.activeField?.name ?? "Selected field"
        let count = viewModel.recommendations.count
        if count == 0 {
            return "\(fieldName) · Preparing recommendations"
        }
        return "\(fieldName) · \(count) recommendation\(count == 1 ? "" : "s")"
    }
}
