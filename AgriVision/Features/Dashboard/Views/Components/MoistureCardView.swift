import SwiftUI
import Charts

struct MoistureCardView: View {
    var moisture: Int?
    var body: some View {
        LiquidGlassCard {
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .foregroundColor(.cyan) // matched light blue
                        .shadow(radius: 1)
                    Text("Soil Moisture")
                        .textStyle(.caption)
                        .foregroundColor(Theme.Colors.primary)
                    Spacer()
                    Image(systemName: "arrow.up")
                        .textStyle(.caption)
                        .foregroundColor(Theme.Colors.primaryMedium)
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)
                
                Spacer(minLength: 0)
                
                ZStack(alignment: .bottom) {
                    ZStack {
                        Circle()
                            .trim(from: 0.5, to: 1.0)
                            .stroke(Color.gray.opacity(0.2), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .padding(4)
                        
                        Circle()
                            .trim(from: 0.5, to: 0.5 + (0.5 * CGFloat(moisture ?? 0) / 100))
                            .stroke(Theme.Colors.primaryMedium, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .padding(4)
                    }
                    .frame(width: 80, height: 80)
                    .frame(height: 40, alignment: .top) // Clip perfectly to the top half
                    .clipped()
                    
                    Text(moisture.map { "\($0)%" } ?? "--")
                        .textStyle(.bodyStrong)
                        .foregroundColor(Theme.Colors.primary)
                        .padding(.bottom, -2)
                }
                .padding(.top, 10)
                
                Spacer(minLength: 0)
                
                Text("Optimal Value: 30-50")
                    .textStyle(.caption)
                    .foregroundColor(Theme.Colors.primaryMedium)
                
                Spacer(minLength: 0)
                
                if #available(iOS 16.0, *) {
                    let chartData: [Double] = moisture.map { [Double($0)] } ?? []
                    Chart {
                        ForEach(0..<chartData.count, id: \.self) { index in
                            LineMark(
                                x: .value("Time", index),
                                y: .value("Moisture", chartData[index])
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Theme.Colors.primaryMedium)
                            
                            AreaMark(
                                x: .value("Time", index),
                                y: .value("Moisture", chartData[index])
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Theme.Colors.primaryLight.opacity(0.3), Theme.Colors.primaryLight.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartYScale(domain: 30...80)
                    .frame(height: 38)
                }
            }
        }
    }
}
