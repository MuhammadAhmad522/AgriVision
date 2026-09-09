import SwiftUI
import Charts

struct SoilTempDetailView: View {
    var surfaceTemp: Double?
    var depthTemp: Double?
    var cropType: String
    
    private struct TempComparison: Identifiable {
        let id = UUID()
        let layer: String
        let temp: Double?
        let color: Color
        let desc: String
    }
    
    private var layers: [TempComparison] {
        [
            TempComparison(layer: "Surface Layer (T0)", temp: surfaceTemp, color: .orange, desc: "Direct sunlight interaction zone affecting seed germination and surface evaporation."),
            TempComparison(layer: "10cm Root Zone (T10)", temp: depthTemp, color: Theme.Colors.primaryMedium, desc: "Subsurface soil temperature governing root cellular division and microbial nitrogen fixation.")
        ]
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Dual Metric Cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    tempTile(
                        title: "Surface (T0)",
                        value: surfaceTemp.map { String(format: "%.1f°C", $0) } ?? "--",
                        icon: "sun.max.fill",
                        tint: .orange
                    )
                    tempTile(
                        title: "10cm Depth (T10)",
                        value: depthTemp.map { String(format: "%.1f°C", $0) } ?? "--",
                        icon: "thermometer.medium",
                        tint: Theme.Colors.primaryMedium
                    )
                }
                
                // Comparative Bar Chart
                VStack(alignment: .leading, spacing: 14) {
                    Text("Thermal Layer Comparison")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.Colors.primary)
                    
                    Chart {
                        ForEach(layers) { item in
                            BarMark(
                                x: .value("Layer", item.layer),
                                y: .value("Temp (°C)", item.temp ?? 0)
                            )
                            .foregroundStyle(item.color)
                            .cornerRadius(8)
                            .annotation(position: .top) {
                                Text(item.temp.map { String(format: "%.1f°C", $0) } ?? "--")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(item.color)
                            }
                        }
                    }
                    .frame(height: 180)
                }
                .padding(20)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
                
                // Agronomic Root Thermal Advice
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "thermometer.medium")
                            .foregroundColor(Theme.Colors.primaryMedium)
                        Text("Root-Zone Thermal Guidance")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.Colors.primary)
                    }
                    
                    Text("Optimal root zone temperature for \(cropType) is 18°C–28°C. Higher temperatures accelerate soil drying, while temperatures below 12°C slow root vegetative growth.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.primaryMedium.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Theme.Colors.primaryMedium.opacity(0.2), lineWidth: 1)
                )
            }
            .padding(20)
        }
    }
    
    private func tempTile(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(tint)
                Spacer()
            }
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.primary)
        }
        .padding(16)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
    }
}
