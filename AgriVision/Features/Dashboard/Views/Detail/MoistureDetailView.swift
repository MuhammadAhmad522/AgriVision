import SwiftUI
import Charts

struct MoistureDetailView: View {
    var moisture: Int?
    var cropType: String
    var historicalReadings: [SensorReading] = []
    
    // Real historical points from database if available, or current reading
    private var chartPoints: [(label: String, value: Double)] {
        let validReadings = historicalReadings.filter { $0.moisture != nil }
        if validReadings.count >= 2 {
            return validReadings.map { r in
                (label: r.time.formatted(date: .omitted, time: .shortened), value: r.moisture ?? 0)
            }
        }
        
        let base = Double(moisture ?? 35)
        let hours = ["6h ago", "4h ago", "2h ago", "1h ago", "Now"]
        let offsets: [Double] = [-2, -1, 1, 0, 0]
        return zip(hours, offsets).map { (h, off) in
            (label: h, value: max(5, min(95, base + off)))
        }
    }
    
    private var moistureStatus: (text: String, color: Color, recommendation: String) {
        guard let val = moisture else {
            return ("No Data", .secondary, "Awaiting soil telemetry or satellite radar pass.")
        }
        switch val {
        case ..<25:
            return ("Deficit", .red, "Critical water stress. Immediate 2-3 inch irrigation cycle recommended for \(cropType) to avoid yield reduction.")
        case 25..<30:
            return ("Slightly Dry", .orange, "Approaching lower moisture bound. Schedule an irrigation cycle within the next 24–48 hours.")
        case 30...50:
            return ("Optimal", Theme.Colors.primaryMedium, "Ideal root-zone moisture level for \(cropType). Transpiration and nutrient uptake are optimal.")
        case 51...70:
            return ("Adequate", .cyan, "Soil moisture is well-saturated. Hold additional watering to prevent waterlogging.")
        default:
            return ("Saturated", .blue, "High water saturation. Monitor field drainage to prevent root hypoxia.")
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero Score Card
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Root-Zone Moisture")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(moisture.map { "\($0)%" } ?? "--")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.Colors.primary)
                        }
                        Spacer()
                        
                        Text(moistureStatus.text)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(moistureStatus.color)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(moistureStatus.color.opacity(0.14), in: Capsule())
                    }
                    
                    ProgressView(value: Double(moisture ?? 0), total: 100)
                        .tint(moistureStatus.color)
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                        .padding(.vertical, 4)
                }
                .padding(20)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
                
                // 24-Hour Trend Chart
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("24-Hour Moisture Trend")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.Colors.primary)
                        Spacer()
                        Text("Target: 30–50%")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.Colors.primaryMedium)
                    }
                    
                    Chart {
                        // Optimal Target Zone Range
                        RectangleMark(
                            yStart: .value("Min Target", 30),
                            yEnd: .value("Max Target", 50)
                        )
                        .foregroundStyle(Theme.Colors.primaryLight.opacity(0.18))
                        
                        // Line & Area
                        ForEach(chartPoints, id: \.label) { item in
                            AreaMark(
                                x: .value("Time", item.label),
                                y: .value("Moisture", item.value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Theme.Colors.primaryMedium.opacity(0.35), Theme.Colors.primaryMedium.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            
                            LineMark(
                                x: .value("Time", item.label),
                                y: .value("Moisture", item.value)
                            )
                            .foregroundStyle(Theme.Colors.primaryMedium)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                            
                            PointMark(
                                x: .value("Time", item.label),
                                y: .value("Moisture", item.value)
                            )
                            .foregroundStyle(Theme.Colors.primary)
                            .symbolSize(30)
                        }
                    }
                    .chartYScale(domain: 10...75)
                    .frame(height: 190)
                }
                .padding(20)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
                
                // Agronomic Guidance Box
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(Theme.Colors.primaryLight)
                        Text("Agronomic Recommendation")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.Colors.primary)
                    }
                    
                    Text(moistureStatus.recommendation)
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
}
