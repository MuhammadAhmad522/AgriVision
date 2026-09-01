import SwiftUI

struct PHLevelCardView: View {
    var entries: [SensorFleetEntry]

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
        VStack(spacing: 0) {
            header(subtitle: nil)
            
            Spacer(minLength: 0)
            
            VStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 24))
                    .foregroundColor(Theme.Colors.primaryMedium.opacity(0.4))
                
                Text("No Sensor Paired")
                    .textStyle(.captionStrong)
                    .foregroundColor(Theme.Colors.primary)
                
                Text("Connect an IoT soil probe to monitor live pH levels.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func sensorPage(_ entry: SensorFleetEntry) -> some View {
        VStack(spacing: 0) {
            header(subtitle: entries.count > 1 ? entry.displayName : nil)

            Spacer()

            VStack(spacing: 4) {
                Gauge(value: entry.reading?.ph ?? 4, in: 4...9) {
                    EmptyView()
                } currentValueLabel: {
                    Text(entry.reading?.ph.map { String(format: "%.1f", $0) } ?? "--")
                        .textStyle(.captionStrong)
                        .foregroundColor(Theme.Colors.primary)
                }
                .gaugeStyle(.linearCapacity)
                .tint(Gradient(colors: [.red, .orange, .yellow, .green, .blue, .indigo, .purple]))
            }
            .padding(.horizontal, 16)
            .opacity(entry.isOnline ? 1.0 : 0.4)

            Spacer()

            statusCaption(for: entry)
                .padding(.bottom, 22)
        }
    }

    private func header(subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: "flask.fill") // Using standard flask icon
                    .foregroundColor(Theme.Colors.primaryLight)
                Text("Soil pH Level")
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
        if entry.reading?.ph != nil, !entry.isOnline {
            Text("Offline · last seen \(entry.lastSeen.map { $0.formatted(.relative(presentation: .named)) } ?? "a while ago")")
                .textStyle(.caption)
                .foregroundColor(.orange)
        } else if entry.reading?.ph != nil {
            Text("Live sensor reading")
                .textStyle(.caption)
                .foregroundColor(Theme.Colors.primaryMedium)
        } else {
            Text("Waiting for sensor data")
                .textStyle(.caption)
                .foregroundColor(Theme.Colors.primaryMedium)
        }
    }
}
