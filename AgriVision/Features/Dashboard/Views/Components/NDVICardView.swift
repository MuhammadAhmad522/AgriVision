import SwiftUI

struct NDVICardView: View {
    var ndvi: Double?
    var body: some View {
        LiquidGlassCard(edge: .trailing) {
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "map.fill")
                        .foregroundColor(Theme.Colors.primaryLight)
                    Text("NDVI")
                        .textStyle(.caption)
                        .foregroundColor(Theme.Colors.primary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)
                
                Spacer()
                
                VStack(spacing: 8) {
                    Text(ndvi.map { String(format: "%.2f", $0) } ?? "--")
                        .textStyle(.title2)
                        .foregroundColor(Theme.Colors.primary)
                    
                    Gauge(value: ndvi ?? 0, in: 0...1) {
                        EmptyView()
                    }
                    .gaugeStyle(.linearCapacity)
                    .tint(Gradient(colors: [.orange, .yellow, .green]))
                }
                .padding(.horizontal, 16)
                
                Spacer()
                
                Text(ndvi == nil ? "Satellite pending" : "Latest acquisition")
                    .textStyle(.caption)
                    .foregroundColor(Theme.Colors.primaryMedium)
                    .padding(.bottom, 22)
            }
        }
    }
}
