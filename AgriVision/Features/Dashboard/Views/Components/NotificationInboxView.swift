import SwiftUI

/// The farmer's notification inbox.
///
/// Replaces a plain `List` of title/body rows. Every notification looked the same there,
/// so an agronomist's urgent "do not spray this field" sat visually level with a routine
/// system notice, and nothing said which field a message was about or who sent it.
struct NotificationInboxView: View {
    @ObservedObject var viewModel: DashboardViewModel
    var onOpenRecommendation: () -> Void
    var onDismiss: () -> Void

    @State private var scope: Scope = .all

    enum Scope: String, CaseIterable, Identifiable {
        case all = "All"
        case expert = "From agronomist"

        var id: String { rawValue }
    }

    private var visible: [UserNotification] {
        switch scope {
        case .all: return viewModel.notifications
        case .expert: return viewModel.expertAdvisories
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.notifications.isEmpty {
                    emptyState
                } else {
                    List {
                        if !viewModel.expertAdvisories.isEmpty {
                            Picker("Scope", selection: $scope) {
                                ForEach(Scope.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                        }

                        ForEach(visible) { notification in
                            NotificationRow(notification: notification)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if !notification.isRead {
                                        viewModel.markNotificationRead(notification)
                                    }
                                    if notification.referenceType == "recommendation" {
                                        onOpenRecommendation()
                                    }
                                }
                        }

                        if visible.isEmpty {
                            Text("No advice from your agronomist yet.")
                                .textStyle(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 24)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.unreadNotificationsCount > 0 {
                        Button("Mark all read") { viewModel.markAllNotificationsRead() }
                            .font(.footnote)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: onDismiss)
                }
            }
            .refreshable { await viewModel.refreshNotifications() }
            // Advice is time-sensitive, so the inbox refreshes itself while open rather
            // than only when the dashboard happens to reload.
            .task { await viewModel.pollNotifications() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bell.slash")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("No notifications")
                .textStyle(.body)
                .foregroundColor(.secondary)
            Text("Advice from your agronomist will appear here.")
                .textStyle(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

private struct NotificationRow: View {
    let notification: UserNotification

    private var accent: Color {
        switch notification.priority {
        case .urgent: return .red
        case .high: return .orange
        case .normal: return Theme.Colors.primaryMedium
        case .low: return .gray
        }
    }

    private var priorityLabel: String? {
        switch notification.priority {
        case .urgent: return "URGENT"
        case .high: return "HIGH PRIORITY"
        case .normal, .low: return nil
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Priority reads as a colour bar rather than a word buried in body text.
            RoundedRectangle(cornerRadius: 2)
                .fill(accent)
                .frame(width: 3)
                .opacity(notification.isRead ? 0.35 : 1)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(notification.title)
                        .textStyle(.bodyStrong)
                        .foregroundColor(notification.isRead ? .secondary : Theme.Colors.textPrimary)
                    Spacer(minLength: 4)
                    if !notification.isRead {
                        Circle().fill(accent).frame(width: 8, height: 8)
                    }
                }

                if let label = priorityLabel {
                    Text(label)
                        .font(.caption2.weight(.bold))
                        .foregroundColor(accent)
                }

                Text(notification.body)
                    .textStyle(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Provenance: which field, and who said it. A farmer with several fields
                // cannot act on advice that does not say where it applies.
                HStack(spacing: 6) {
                    if let fieldName = notification.fieldName {
                        Label(fieldName, systemImage: "map")
                            .font(.caption2)
                            .foregroundColor(Theme.Colors.primaryMedium)
                    }
                    if notification.isFromExpert, let sender = notification.createdByEmail {
                        Label(sender, systemImage: "person.badge.shield.checkmark")
                            .font(.caption2)
                            .foregroundColor(Theme.Colors.primaryMedium)
                            .lineLimit(1)
                    }
                }

                Text(notification.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 6)
    }
}
