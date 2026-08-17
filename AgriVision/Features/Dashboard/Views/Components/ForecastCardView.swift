import SwiftUI

struct ForecastCardView: View {
    let days: [FieldWeatherSoil.ForecastDay]

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.primaryLight)
                    Text("Forecast")
                        .textStyle(.caption)
                        .foregroundColor(Theme.Colors.primary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)

                Spacer()

                VStack(spacing: 5) {
                    ForEach(Array(days.prefix(3))) { day in
                        HStack(spacing: 4) {
                            Text(shortDate(day.date))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(width: 32, alignment: .leading)
                            Text(day.tempMaxC.map { "\(Int(round($0)))°" } ?? "--")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Theme.Colors.primary)
                            Spacer()
                            HStack(spacing: 2) {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.cyan)
                                Text(day.rainMm.map { String(format: "%.1f", $0) } ?? "0")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.cyan)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)

                Spacer()

                Text(days.isEmpty ? "Weather pending" : "Rain shown in mm")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)
            }
        }
    }

    private func shortDate(_ value: String) -> String {
        value.count >= 10 ? String(value.suffix(5)) : value
    }
}
