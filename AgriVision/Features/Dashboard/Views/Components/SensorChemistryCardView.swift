import SwiftUI

struct SensorChemistryCardView: View {
    let entries: [SensorFleetEntry]

    var body: some View {
        LiquidGlassCard(edge: .trailing) {
            if entries.isEmpty {
                emptyState
            } else {
                TabView {
                    ForEach(entries) { entry in
                        sensorPage(entry)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: entries.count > 1 ? .automatic : .never))
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(subtitle: nil)
            Spacer()
            Text("No sensor paired")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
        }
    }

    @ViewBuilder
    private func sensorPage(_ entry: SensorFleetEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(subtitle: entries.count > 1 ? entry.displayName : nil)

            Spacer()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                chemItem("N", entry.reading?.npk_n, color: .blue)
                chemItem("P", entry.reading?.npk_p, color: .orange)
                chemItem("K", entry.reading?.npk_k, color: .purple)
                chemItem("EC", entry.reading?.ec, color: .teal)
            }
            .padding(.horizontal, 12)
            .opacity(entry.isOnline ? 1.0 : 0.4)

            Spacer()

            statusCaption(for: entry)
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
        }
    }

    private func header(subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Image(systemName: "testtube.2")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Colors.primaryLight)
                Text("Soil Chemistry")
                    .textStyle(.caption)
                    .foregroundColor(Theme.Colors.primary)
                Spacer()
            }
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
    }

    @ViewBuilder
    private func statusCaption(for entry: SensorFleetEntry) -> some View {
        let hasChemistry = [entry.reading?.ec, entry.reading?.npk_n, entry.reading?.npk_p, entry.reading?.npk_k].contains { $0 != nil }
        if hasChemistry, !entry.isOnline {
            Text("Offline · last seen \(entry.lastSeen.map { $0.formatted(.relative(presentation: .named)) } ?? "a while ago")")
                .font(.system(size: 11))
                .foregroundColor(.orange)
                .lineLimit(1)
        } else if hasChemistry {
            Text("Live sensor values")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
        } else {
            Text("Probe not reporting")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    private func chemItem(_ name: String, _ value: Double?, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
                .frame(width: 18, height: 18)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))

            Text(value.map { String(format: "%.1f", $0) } ?? "--")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.Colors.primary)
            Spacer(minLength: 0)
        }
    }
}
