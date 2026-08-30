import SwiftUI

struct SensorLiveCardView: View {
    let entries: [SensorFleetEntry]

    var body: some View {
        LiquidGlassCard {
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

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Temp")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(entry.reading?.temperature.map { String(format: "%.1f°C", $0) } ?? "--")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.Colors.primary)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Moisture")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(entry.reading?.moisture.map { String(format: "%.0f%%", $0) } ?? "--")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.Colors.primary)
                }
            }
            .padding(.horizontal, 14)
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
                Image(systemName: "sensor.tag.radiowaves.forward.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Colors.primaryLight)
                Text("Live Sensor")
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
        if let reading = entry.reading, !entry.isOnline {
            Text("Offline · last seen \(reading.time.formatted(.relative(presentation: .named)))")
                .font(.system(size: 11))
                .foregroundColor(.orange)
                .lineLimit(1)
        } else if let reading = entry.reading {
            Text("Updated \(reading.time.formatted(.relative(presentation: .named)))")
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.primaryMedium)
                .lineLimit(1)
        } else {
            Text("Waiting for readings")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}
