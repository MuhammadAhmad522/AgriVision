import SwiftUI

struct VegetationIndicesCardView: View {
    let statistics: [String: VegetationStatistics]?

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.primaryLight)
                    Text("Vegetation")
                        .textStyle(.caption)
                        .foregroundColor(Theme.Colors.primary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)

                Spacer()

                VStack(spacing: 6) {
                    indexRow("NDVI", statistics?["ndvi"]?.mean)
                    indexRow("EVI", statistics?["evi"]?.mean)
                    indexRow("EVI2", statistics?["evi2"]?.mean)
                }
                .padding(.horizontal, 14)

                Spacer()

                Text("Scene averages")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)
            }
        }
    }

    private func indexRow(_ name: String, _ value: Double?) -> some View {
        HStack {
            Text(name).textStyle(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value.map { String(format: "%.3f", $0) } ?? "--")
                .textStyle(.captionStrong)
                .foregroundStyle(Theme.Colors.primary)
        }
    }
}
