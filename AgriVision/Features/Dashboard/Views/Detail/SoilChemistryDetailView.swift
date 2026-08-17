import SwiftUI
import Charts

struct SoilChemistryDetailView: View {
    var reading: SensorReading?
    var sensorStatus: String
    var cropType: String
    
    private struct ChemMetric: Identifiable {
        let id = UUID()
        let name: String
        let current: Double?
        let target: Double
        let unit: String
        let color: Color
        let role: String
    }
    
    private var metricsList: [ChemMetric] {
        [
            ChemMetric(name: "Nitrogen (N)", current: reading?.npk_n, target: 120.0, unit: "mg/kg", color: .blue, role: "Leaf & Vegetative Biomass"),
            ChemMetric(name: "Phosphorus (P)", current: reading?.npk_p, target: 45.0, unit: "mg/kg", color: .orange, role: "Root Development & Tillering"),
            ChemMetric(name: "Potassium (K)", current: reading?.npk_k, target: 180.0, unit: "mg/kg", color: .purple, role: "Grain Filling & Drought Resistance"),
            ChemMetric(name: "EC (Salinity)", current: reading?.ec, target: 1.5, unit: "mS/cm", color: .teal, role: "Soil Salt & Osmotic Stress")
        ]
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero 4-Bar Comparison Chart
                VStack(alignment: .leading, spacing: 14) {
                    Text("NPK & Electrical Conductivity Levels")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.Colors.primary)
                    
                    Chart {
                        ForEach(metricsList) { item in
                            // Current Reading Bar
                            BarMark(
                                x: .value("Nutrient", item.name),
                                y: .value("Value", item.current ?? 0)
                            )
                            .foregroundStyle(item.color)
                            .cornerRadius(6)
                            .annotation(position: .top) {
                                Text(item.current.map { String(format: "%.1f", $0) } ?? "--")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(item.color)
                            }
                        }
                    }
                    .frame(height: 180)
                }
                .padding(20)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
                
                // Detailed Breakdown List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nutrient Channel Breakdown")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.Colors.primary)
                    
                    ForEach(metricsList) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.name)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(item.color)
                                Spacer()
                                Text(item.current.map { String(format: "%.1f %@", $0, item.unit) } ?? "No reading")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Theme.Colors.primary)
                            }
                            
                            HStack {
                                Text(item.role)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Target: \(Int(item.target)) \(item.unit)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(12)
                        .background(item.color.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(20)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
                
                // Agronomic Advice Box
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "testtube.2")
                            .foregroundColor(Theme.Colors.primaryMedium)
                        Text("Fertilizer Recommendation")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.Colors.primary)
                    }
                    
                    Text("Maintain balanced N:P:K ratios for \(cropType). When applying Nitrogen top-dressings (Urea/DAP), ensure sufficient root-zone moisture to facilitate chemical dissolution and avoid root burning.")
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
