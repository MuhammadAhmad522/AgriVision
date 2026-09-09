import SwiftUI

struct UVIndexCardView: View {
    let snapshot: UVISnapshot?
    let status: String?

    var body: some View {
        LiquidGlassCard(edge: .trailing) {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.orange)
                    Text("UV Index")
                        .textStyle(.caption)
                        .foregroundColor(Theme.Colors.primary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)

                Spacer()

                VStack(spacing: 2) {
                    Text(snapshot?.uvi.map { String(format: "%.1f", $0) } ?? "--")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(uvColor)
                    Text(riskLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(uvColor)
                }

                Spacer()

                Text(snapshot == nil ? (status?.capitalized ?? "Pending") : "Live AgroMonitoring")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)
            }
        }
    }

    private var riskLabel: String {
        guard let value = snapshot?.uvi else { return "No reading" }
        switch value {
        case ..<3: return "Low"
        case ..<6: return "Moderate"
        case ..<8: return "High"
        case ..<11: return "Very high"
        default: return "Extreme"
        }
    }

    private var uvColor: Color {
        guard let value = snapshot?.uvi else { return .secondary }
        if value < 3 { return .green }
        if value < 6 { return .yellow }
        if value < 8 { return .orange }
        return .red
    }
}
