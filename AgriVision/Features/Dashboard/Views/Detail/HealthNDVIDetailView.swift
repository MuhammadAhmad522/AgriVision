import SwiftUI
import Charts

struct HealthNDVIDetailView: View {
    var healthScore: Double?
    var cropType: String
    var statistics: [String: VegetationStatistics]?
    
    private var ndviValue: Double {
        statistics?["ndvi"]?.mean ?? healthScore ?? 0.0
    }
    
    private var ndviClassification: (label: String, color: Color, description: String) {
        switch ndviValue {
        case 0.7...1.0:
            return ("High Vigor & Dense Canopy", Theme.Colors.primaryMedium, "Excellent biomass accumulation. Photosynthetic activity and chlorophyll absorption are peak for \(cropType).")
        case 0.5..<0.7:
            return ("Moderate Vegetative Growth", .green, "Healthy canopy coverage with normal leaf area index. Maintain regular nutrient and watering cycles.")
        case 0.3..<0.5:
            return ("Sparse or Emerging Canopy", .orange, "Moderate to low vegetation density. Can correspond to early emergence or localized moisture/nutrient stress.")
        default:
            return ("Low Vigor / Stressed", .red, "Significant biomass stress or bare soil detected. Inspect for pest infestation, salinity, or waterlogging.")
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero Score Card
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sentinel-2 NDVI Index")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(String(format: "%.2f", ndviValue))
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.Colors.primary)
                        }
                        Spacer()
                        
                        Text(ndviClassification.label)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(ndviClassification.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(ndviClassification.color.opacity(0.14), in: Capsule())
                            .multilineTextAlignment(.trailing)
                    }
                    
                    // Linear Multi-Gradient Gauge
                    VStack(alignment: .leading, spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [.red, .orange, .yellow, .green, Theme.Colors.primaryMedium],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 12)
                                
                                // Indicator Pin
                                Capsule()
                                    .fill(Color.white)
                                    .frame(width: 4, height: 20)
                                    .shadow(color: .black.opacity(0.4), radius: 2)
                                    .offset(x: max(0, min(geo.size.width - 4, CGFloat(ndviValue) * geo.size.width)))
                            }
                        }
                        .frame(height: 20)
                        
                        HStack {
                            Text("0.0 Bare").font(.system(size: 10)).foregroundColor(.secondary)
                            Spacer()
                            Text("0.5 Moderate").font(.system(size: 10)).foregroundColor(.secondary)
                            Spacer()
                            Text("1.0 Dense").font(.system(size: 10)).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(20)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
                
                // Statistical Distribution Card
                if let ndviStats = statistics?["ndvi"] {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Field Spatial Statistics")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.Colors.primary)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            statTile("Mean Index", String(format: "%.3f", ndviStats.mean ?? ndviValue))
                            statTile("Min (Stressed Zone)", ndviStats.min.map { String(format: "%.3f", $0) } ?? "--")
                            statTile("Max (Peak Vigor)", ndviStats.max.map { String(format: "%.3f", $0) } ?? "--")
                            statTile("Std Deviation", ndviStats.standardDeviation.map { String(format: "%.3f", $0) } ?? "--")
                        }
                    }
                    .padding(20)
                    .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
                }
                
                // Agronomic Interpretation
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(Theme.Colors.primaryMedium)
                        Text("Canopy Analysis for \(cropType)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.Colors.primary)
                    }
                    
                    Text(ndviClassification.description)
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
    
    private func statTile(_ label: String, _ val: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 11)).foregroundColor(.secondary)
            Text(val).font(.system(size: 16, weight: .bold)).foregroundColor(Theme.Colors.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.02), in: RoundedRectangle(cornerRadius: 12))
    }
}
