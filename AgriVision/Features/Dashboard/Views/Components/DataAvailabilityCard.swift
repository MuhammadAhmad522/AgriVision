import SwiftUI

struct DataAvailabilityCard: View {
    let items: [DataAvailabilityItem]
    let onRetry: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(Theme.Colors.primaryMedium)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Data availability").textStyle(.bodyStrong)
                        Text("\(items.count) source\(items.count == 1 ? "" : "s") still preparing or unavailable")
                            .textStyle(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down").rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .foregroundStyle(Theme.Colors.primary)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(color(for: item.status)).frame(width: 8, height: 8).padding(.top, 5)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(item.title) · \(label(for: item.status))").textStyle(.captionStrong)
                            if let message = item.message { Text(message).textStyle(.caption).foregroundStyle(.secondary) }
                            if let date = item.lastUpdated { Text("Updated \(date.formatted(.relative(presentation: .named)))").textStyle(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
                if items.contains(where: \.retryable) {
                    Button(action: onRetry) { Label("Refresh available sources", systemImage: "arrow.clockwise") }
                        .textStyle(.captionStrong).foregroundStyle(Theme.Colors.primaryMedium)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.Colors.primaryLight.opacity(0.5)))
    }

    private func label(for status: DataSourceStatus) -> String {
        switch status {
        case .available: return "Available"
        case .pending: return "Preparing"
        case .stale: return "Needs refresh"
        case .unavailable: return "Unavailable"
        case .unsupported: return "Not supported"
        case .notConfigured: return "Not connected"
        }
    }

    private func color(for status: DataSourceStatus) -> Color {
        switch status {
        case .pending, .notConfigured, .unsupported: return Theme.Colors.primaryMedium
        case .stale: return Theme.Colors.warning
        case .unavailable: return .red
        case .available: return Theme.Colors.primaryLight
        }
    }
}
