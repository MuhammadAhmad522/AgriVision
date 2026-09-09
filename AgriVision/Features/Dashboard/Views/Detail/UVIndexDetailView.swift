import SwiftUI
import Charts

struct UVIndexDetailView: View {
    var snapshot: UVISnapshot?
    var status: String?
    
    private var uviValue: Double {
        snapshot?.uvi ?? 4.2
    }
    
    // Simulated daylight solar curve peaking around current UVI
    private var diurnalCurve: [(hour: String, uvi: Double)] {
        let peak = max(1.0, uviValue)
        let hours = ["6AM", "8AM", "10AM", "12PM", "2PM", "4PM", "6PM", "8PM"]
        let factors: [Double] = [0.1, 0.35, 0.75, 1.0, 0.85, 0.45, 0.15, 0.0]
        return zip(hours, factors).map { (hour, factor) in
            (hour: hour, uvi: peak * factor)
        }
    }
    
    private var uvRisk: (tier: String, color: Color, advice: String) {
        switch uviValue {
        case ..<3:
            return ("Low Hazard", .green, "Minimal solar stress on crop leaves. Safe conditions for foliar nutrient sprays.")
        case 3..<6:
            return ("Moderate Hazard", .yellow, "Standard solar radiation. Normal daytime photosynthetic activity.")
        case 6..<8:
            return ("High Radiation", .orange, "Accelerated evapotranspiration. Avoid chemical pesticide application during midday peak.")
        case 8..<11:
            return ("Very High Solar Stress", .red, "Severe solar radiation. Risk of leaf scorch on tender seedlings. Ensure root-zone moisture.")
        default:
            return ("Extreme Hazard", .purple, "Extreme UV exposure and thermal stress. Maximize irrigation buffers to counter high transpirational loss.")
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero Score Card
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Solar Ultraviolet Index")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(snapshot?.uvi.map { String(format: "%.1f", $0) } ?? "--")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundColor(uvRisk.color)
                        }
                        Spacer()
                        
                        Text(uvRisk.tier)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(uvRisk.color)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(uvRisk.color.opacity(0.14), in: Capsule())
                    }
                    
                    ProgressView(value: min(12.0, uviValue), total: 12.0)
                        .tint(uvRisk.color)
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                }
                .padding(20)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
                
                // Diurnal Solar UV Curve Chart
                VStack(alignment: .leading, spacing: 14) {
                    Text("Daylight UV Radiation Profile")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.Colors.primary)
                    
                    Chart {
                        ForEach(diurnalCurve, id: \.hour) { item in
                            AreaMark(
                                x: .value("Time", item.hour),
                                y: .value("UV Index", item.uvi)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.35), Color.orange.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            
                            LineMark(
                                x: .value("Time", item.hour),
                                y: .value("UV Index", item.uvi)
                            )
                            .foregroundStyle(Color.orange)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            
                            PointMark(
                                x: .value("Time", item.hour),
                                y: .value("UV Index", item.uvi)
                            )
                            .foregroundStyle(Color.orange)
                            .symbolSize(20)
                        }
                    }
                    .frame(height: 180)
                }
                .padding(20)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
                
                // Agronomic Solar Guidance
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(.orange)
                        Text("Solar Radiation Advisory")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.Colors.primary)
                    }
                    
                    Text(uvRisk.advice)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                )
            }
            .padding(20)
        }
    }
}
