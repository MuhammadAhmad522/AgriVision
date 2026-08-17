import SwiftUI

struct SoilTempCardView: View {
    var surfaceTemp: Double?
    var depthTemp: Double?
    
    var body: some View {
        LiquidGlassCard {
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "thermometer.medium")
                        .foregroundColor(.orange)
                    Text("Soil Temp")
                        .textStyle(.caption)
                        .foregroundColor(Theme.Colors.primary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Surface")
                                .textStyle(.captionStrong)
                                .foregroundColor(.gray)
                            Text(surfaceTemp.map { String(format: "%.1f°C", $0) } ?? "--")
                                .textStyle(.bodyStrong)
                                .foregroundColor(Theme.Colors.primary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("10cm Depth")
                                .textStyle(.captionStrong)
                                .foregroundColor(.gray)
                            Text(depthTemp.map { String(format: "%.1f°C", $0) } ?? "--")
                                .textStyle(.bodyStrong)
                                .foregroundColor(Theme.Colors.primary)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                
                Spacer()
                
                Text("Satellite Ground Scan")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)
            }
        }
    }
}
