import SwiftUI
import Charts

struct VegetationIndicesDetailView: View {
    var statistics: [String: VegetationStatistics]?
    
    private struct IndexItem: Identifiable {
        let id = UUID()
        let key: String
        let name: String
        let value: Double?
        let color: Color
        let desc: String
    }
    
    private var indexList: [IndexItem] {
        [
            IndexItem(key: "ndvi", name: "NDVI (Canopy Vigor)", value: statistics?["ndvi"]?.mean, color: Theme.Colors.primaryMedium, desc: "Normalized Difference Vegetation Index measuring chlorophyll absorption and active green biomass."),
            IndexItem(key: "evi", name: "EVI (Enhanced Vigor)", value: statistics?["evi"]?.mean, color: .green, desc: "Enhanced Vegetation Index optimized for high-biomass canopy regions with reduced atmospheric noise."),
            IndexItem(key: "evi2", name: "EVI2 (Two-Band EVI)", value: statistics?["evi2"]?.mean, color: .mint, desc: "Calculated from Red and NIR bands, maintaining high correlation with canopy leaf area index."),
            IndexItem(key: "ndwi", name: "NDWI (Leaf Water)", value: statistics?["ndwi"]?.mean, color: .cyan, desc: "Normalized Difference Water Index assessing plant leaf internal water content and moisture stress."),
            IndexItem(key: "ndre", name: "NDRE (Chlorophyll)", value: statistics?["ndre"]?.mean, color: .teal, desc: "Red-Edge index sensitive to mid-to-late stage nitrogen content in dense, mature canopies.")
        ]
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Multispectral Comparison Bar Chart
                VStack(alignment: .leading, spacing: 14) {
                    Text("Sentinel-2 Multispectral Scene Averages")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.Colors.primary)
                    
                    Chart {
                        ForEach(indexList) { item in
                            BarMark(
                                x: .value("Index", item.key.uppercased()),
                                y: .value("Score", item.value ?? 0)
                            )
                            .foregroundStyle(item.color)
                            .cornerRadius(6)
                            .annotation(position: .top) {
                                Text(item.value.map { String(format: "%.2f", $0) } ?? "--")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(item.color)
                            }
                        }
                    }
                    .chartYScale(domain: 0...1.0)
                    .frame(height: 180)
                }
                .padding(20)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
                
                // Detailed Breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("Vegetation Band Diagnostics")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.Colors.primary)
                    
                    ForEach(indexList) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.name)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(item.color)
                                Spacer()
                                Text(item.value.map { String(format: "%.3f", $0) } ?? "Pending")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Theme.Colors.primary)
                            }
                            
                            Text(item.desc)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineSpacing(2)
                        }
                        .padding(14)
                        .background(item.color.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(20)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
            }
            .padding(20)
        }
    }
}
