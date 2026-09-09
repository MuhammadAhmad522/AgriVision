import SwiftUI

struct NDVICardView: View {
    var ndvi: Double?
    var body: some View {
        LiquidGlassCard(edge: .trailing) {
            VStack(spacing: 0) {
                MetricCardHeader(icon: "map.fill", iconColor: Theme.Colors.primaryLight, title: "NDVI")

                Spacer()

                VStack(spacing: 8) {
                    Text(ndvi.map { String(format: "%.2f", $0) } ?? "--")
                        .textStyle(.title3)
                        .foregroundColor(Theme.Colors.primary)

                    Gauge(value: ndvi ?? 0, in: 0...1) {
                        EmptyView()
                    }
                    .gaugeStyle(.linearCapacity)
                    .tint(Gradient(colors: [.orange, .yellow, .green]))
                }
                .padding(.horizontal, 16)

                Spacer()

                MetricCardFooter(text: ndvi == nil ? "Satellite pending" : "Latest acquisition")
            }
        }
    }
}
