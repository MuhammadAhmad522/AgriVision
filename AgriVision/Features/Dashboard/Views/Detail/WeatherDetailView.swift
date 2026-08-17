import SwiftUI
import Charts

struct WeatherDetailView: View {
    var weather: FieldWeatherSoil.WeatherData?
    
    private var forecastList: [FieldWeatherSoil.ForecastDay] {
        weather?.forecastDays ?? []
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero Weather Overview
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(weather?.current.description?.capitalized ?? "Current Conditions")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Text(weather?.current.tempC.map { "\(Int(round($0)))°C" } ?? "--°C")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.Colors.primary)
                        
                        if let firstDay = forecastList.first,
                           let maxT = firstDay.tempMaxC,
                           let minT = firstDay.tempMinC {
                            Text("High: \(Int(round(maxT)))°  •  Low: \(Int(round(minT)))°")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: weatherIconName)
                        .symbolRenderingMode(.multicolor)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 70, height: 70)
                        .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)
                }
                .padding(20)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
                
                // Key Atmospheric Metrics Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    metricTile(title: "Humidity", value: weather?.current.humidity.map { "\(Int(round($0)))%" } ?? "--", icon: "humidity.fill", tint: .cyan)
                    metricTile(title: "Conditions", value: weather?.current.description?.capitalized ?? "--", icon: "cloud.sun.fill", tint: .orange)
                }
                
                // 5-Day High/Low Temperature Trend Chart
                if !forecastList.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("5-Day Temperature Outlook")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.Colors.primary)
                        
                        Chart {
                            ForEach(forecastList) { day in
                                if let maxTemp = day.tempMaxC {
                                    LineMark(
                                        x: .value("Day", formatDay(day.date)),
                                        y: .value("Max Temp", maxTemp)
                                    )
                                    .foregroundStyle(Color.orange)
                                    .symbol(Circle())
                                    .symbolSize(30)
                                    
                                    PointMark(
                                        x: .value("Day", formatDay(day.date)),
                                        y: .value("Max Temp", maxTemp)
                                    )
                                    .annotation(position: .top) {
                                        Text("\(Int(round(maxTemp)))°")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.orange)
                                    }
                                }
                                
                                if let minTemp = day.tempMinC {
                                    LineMark(
                                        x: .value("Day", formatDay(day.date)),
                                        y: .value("Min Temp", minTemp)
                                    )
                                    .foregroundStyle(Color.blue)
                                    .symbol(Circle())
                                    .symbolSize(30)
                                    
                                    PointMark(
                                        x: .value("Day", formatDay(day.date)),
                                        y: .value("Min Temp", minTemp)
                                    )
                                    .annotation(position: .bottom) {
                                        Text("\(Int(round(minTemp)))°")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                        .frame(height: 180)
                        .chartYAxis(.hidden)
                    }
                    .padding(20)
                    .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
                    
                    // Rain Precipitation Forecast
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Rainfall Expected (mm)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.Colors.primary)
                        
                        Chart {
                            ForEach(forecastList) { day in
                                BarMark(
                                    x: .value("Day", formatDay(day.date)),
                                    y: .value("Rain", day.rainMm ?? 0)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.cyan, Color.blue.opacity(0.6)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .cornerRadius(6)
                                .annotation(position: .top) {
                                    if let rain = day.rainMm, rain > 0 {
                                        Text(String(format: "%.1f", rain))
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.cyan)
                                    }
                                }
                            }
                        }
                        .frame(height: 140)
                    }
                    .padding(20)
                    .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
                }
            }
            .padding(20)
        }
    }
    
    private func metricTile(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.Colors.primary)
            }
            Spacer()
        }
        .padding(14)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
    }
    
    private var weatherIconName: String {
        guard let desc = weather?.current.description?.lowercased() else { return "cloud.sun.fill" }
        if desc.contains("rain") { return "cloud.sun.rain.fill" }
        if desc.contains("snow") { return "snowflake" }
        if desc.contains("storm") || desc.contains("thunder") { return "cloud.bolt.rain.fill" }
        if desc.contains("cloud") { return "cloud.fill" }
        if desc.contains("clear") || desc.contains("sun") { return "sun.max.fill" }
        return "cloud.sun.fill"
    }
    
    private func formatDay(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            let out = DateFormatter()
            out.dateFormat = "EEE"
            return out.string(from: date)
        }
        return dateString.count >= 5 ? String(dateString.suffix(5)) : dateString
    }
}
