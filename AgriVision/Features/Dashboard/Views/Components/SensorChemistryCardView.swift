import SwiftUI

struct SensorChemistryCardView: View {
    let reading: SensorReading?
    let sensorStatus: String

    var body: some View {
        LiquidGlassCard(edge: .trailing) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "testtube.2")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.primaryLight)
                    Text("Soil Chemistry")
                        .textStyle(.caption)
                        .foregroundColor(Theme.Colors.primary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)

                Spacer()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    chemItem("N", reading?.npk_n, color: .blue)
                    chemItem("P", reading?.npk_p, color: .orange)
                    chemItem("K", reading?.npk_k, color: .purple)
                    chemItem("EC", reading?.ec, color: .teal)
                }
                .padding(.horizontal, 12)

                Spacer()

                Text(hasChemistry ? "Live sensor values" : (sensorStatus == "not_configured" ? "No sensor paired" : "Probe not reporting"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)
            }
        }
    }

    private var hasChemistry: Bool {
        [reading?.ec, reading?.npk_n, reading?.npk_p, reading?.npk_k].contains { $0 != nil }
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
