import SwiftUI

/// Shared chrome for the "Field Metrics" grid cards (Moisture, pH, NDVI, UV, Forecast,
/// Sensor readings, etc). These cards were each hand-rolling their own header/footer
/// typography and padding, which drifted apart over time — different icon sizes, caption
/// font sizes (9/10/11/12/13pt all appeared for what was supposed to be the same "footer
/// note" role), and inconsistent horizontal insets. Centralizing them here is what keeps
/// new cards visually consistent instead of copy-pasting and drifting again.

/// The title row every metric card starts with: an accent icon, a caption-weight title,
/// and an optional secondary subtitle (e.g. a specific sensor's name when a card pages
/// through more than one sensor).
struct MetricCardHeader: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(title)
                    .textStyle(.caption)
                    .foregroundColor(Theme.Colors.primary)
                Spacer(minLength: 0)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
    }
}

/// The status note every metric card ends with (e.g. "Live sensor reading", "Offline ·
/// last seen 3h ago", "Satellite estimate · Optimal 30-50%"). Allowed to wrap to two lines
/// instead of truncating, since offline/timestamp messages routinely run longer than a
/// single line at caption size.
struct MetricCardFooter: View {
    let text: String
    var color: Color = Theme.Colors.primaryMedium
    /// 16 when this footer is the last thing in the card (the common case); pass 0 when
    /// more content (e.g. a trend chart) follows it below.
    var bottomPadding: CGFloat = 16

    var body: some View {
        Text(text)
            .textStyle(.caption)
            .foregroundColor(color)
            .lineLimit(2)
            .minimumScaleFactor(0.9)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.bottom, bottomPadding)
    }
}

/// One half of a side-by-side metric pair (e.g. Surface/Depth temperature, Temp/Moisture).
/// Uses an equal-width frame rather than a `Spacer()`-separated HStack so both halves
/// always get exactly half the row — a longer label on one side no longer pushes the
/// other value out of alignment.
struct MetricStatColumn: View {
    let label: String
    let value: String
    var alignment: HorizontalAlignment = .leading
    var valueColor: Color = Theme.Colors.primary

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .textStyle(.bodyStrong)
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }
}
