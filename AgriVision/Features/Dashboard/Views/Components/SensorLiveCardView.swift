import SwiftUI

struct SensorLiveCardView: View {
    let reading: SensorReading?
    let sensorStatus: String

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "sensor.tag.radiowaves.forward.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.primaryLight)
                    Text("Live Sensor")
                        .textStyle(.caption)
                        .foregroundColor(Theme.Colors.primary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)

                Spacer()

                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Temp")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(reading?.temperature.map { String(format: "%.1f°C", $0) } ?? "--")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.Colors.primary)
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Moisture")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(reading?.moisture.map { String(format: "%.0f%%", $0) } ?? "--")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.Colors.primary)
                    }
                }
                .padding(.horizontal, 14)

                Spacer()

                Text(reading.map { "Updated \($0.time.formatted(.relative(presentation: .named)))" } ?? statusText)
                    .font(.system(size: 11))
                    .foregroundColor(reading == nil ? .secondary : Theme.Colors.primaryMedium)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)
            }
        }
    }

    private var statusText: String {
        sensorStatus == "not_configured" ? "No sensor paired" : "Waiting for readings"
    }
}
