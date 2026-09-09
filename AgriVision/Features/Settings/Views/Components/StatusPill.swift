import SwiftUI

struct StatusPill: View {
    let status: String

    private var color: Color {
        switch status {
        case "available": return .green
        case "pending", "stale": return .orange
        case "not_configured": return .secondary
        default: return .red
        }
    }

    var body: some View {
        Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}
