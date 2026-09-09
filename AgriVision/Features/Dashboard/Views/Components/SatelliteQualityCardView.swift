import SwiftUI

struct SatelliteQualityCardView: View {
    let snapshot: SatelliteSnapshot?

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Scene Quality", systemImage: "cloud.sun.fill")
                    .textStyle(.captionStrong)
                    .foregroundStyle(Theme.Colors.primary)
                Spacer()
                qualityRow("Cloud", snapshot?.cloudPercent)
                qualityRow("Coverage", snapshot?.coveragePercent)
                Spacer()
                Text(snapshot.map { "Captured \($0.acquiredAt.formatted(date: .abbreviated, time: .omitted))" } ?? "Satellite pending")
                    .textStyle(.caption).foregroundStyle(.secondary)
            }
            .padding(16)
        }
    }

    private func qualityRow(_ name: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(name).textStyle(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(value.map { String(format: "%.0f%%", $0) } ?? "--").textStyle(.captionStrong)
            }
            ProgressView(value: min(max(value ?? 0, 0), 100), total: 100).tint(Theme.Colors.primaryMedium)
        }
    }
}
