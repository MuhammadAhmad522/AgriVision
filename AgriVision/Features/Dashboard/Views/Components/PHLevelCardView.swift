import SwiftUI

struct PHLevelCardView: View {
    var phLevel: Double?
    var sensorStatus: String
    var body: some View {
        LiquidGlassCard(edge: .trailing) {
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "flask.fill") // Using standard flask icon
                        .foregroundColor(Theme.Colors.primaryLight)
                    Text("Soil pH Level")
                        .textStyle(.caption)
                        .foregroundColor(Theme.Colors.primary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)
                
                Spacer()
                
                VStack(spacing: 4) {
                    Gauge(value: phLevel ?? 4, in: 4...9) {
                        EmptyView()
                    } currentValueLabel: {
                        Text(phLevel.map { String(format: "%.1f", $0) } ?? "--")
                            .textStyle(.captionStrong)
                            .foregroundColor(Theme.Colors.primary)
                    }
                    .gaugeStyle(.linearCapacity)
                    .tint(Gradient(colors: [.red, .orange, .yellow, .green, .blue, .indigo, .purple]))
                }
                .padding(.horizontal, 16)
                
                Spacer()
                
                Text(phLevel != nil ? "Live sensor reading" : (sensorStatus == "not_configured" ? "Optional sensor not connected" : "Waiting for sensor data"))
                    .textStyle(.caption)
                    .foregroundColor(Theme.Colors.primaryMedium)
                    .padding(.bottom, 22)
            }
        }
    }
}
