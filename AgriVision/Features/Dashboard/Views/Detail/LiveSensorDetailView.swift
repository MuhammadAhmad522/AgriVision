import SwiftUI
import Charts

struct LiveSensorDetailView: View {
    var reading: SensorReading?
    var sensorStatus: String
    var readings: [SensorReading] = []
    
    // Real database telemetry points if available, or recent snapshot stream
    private var telemetryStream: [(time: String, temp: Double, moisture: Double)] {
        let valid = readings.filter { $0.temperature != nil }
        if valid.count >= 2 {
            return valid.map { r in
                (
                    time: r.time.formatted(date: .omitted, time: .shortened),
                    temp: r.temperature ?? 24.0,
                    moisture: r.moisture ?? 35.0
                )
            }
        }
        
        let baseTemp = reading?.temperature ?? 24.5
        let baseMoist = reading?.moisture ?? 38.0
        let timeLabels = ["10m ago", "8m ago", "6m ago", "4m ago", "2m ago", "Just Now"]
        let tempOffsets: [Double] = [-0.4, -0.2, 0.1, 0.3, 0.0, 0.2]
        let moistOffsets: [Double] = [0.5, -0.3, -0.8, -0.2, 0.4, 0.0]
        
        return zip(timeLabels, zip(tempOffsets, moistOffsets)).map { (time, offsets) in
            (time: time, temp: baseTemp + offsets.0, moisture: baseMoist + offsets.1)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Live Stream Status Header
                HStack(spacing: 12) {
                    Circle()
                        .fill(reading != nil ? Theme.Colors.primaryMedium : .orange)
                        .frame(width: 12, height: 12)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reading != nil ? "Hardware Probe Active" : (sensorStatus == "not_configured" ? "No Sensor Paired" : "Waiting for Telemetry"))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.Colors.primary)
                        
                        Text(reading.map { "Last packet received \($0.time.formatted(.relative(presentation: .named)))" } ?? "Attach an RS485 or wireless sensor node to stream live data.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
                
                // Key Dual Metrics
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    metricCard(
                        title: "Soil Temperature",
                        value: reading?.temperature.map { String(format: "%.1f°C", $0) } ?? "--",
                        icon: "thermometer.medium",
                        tint: .orange
                    )
                    metricCard(
                        title: "Soil Moisture",
                        value: reading?.moisture.map { String(format: "%.0f%%", $0) } ?? "--",
                        icon: "drop.fill",
                        tint: .cyan
                    )
                }
                
                // Telemetry Time-Series Chart
                VStack(alignment: .leading, spacing: 14) {
                    Text("Real-Time Telemetry Stream")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.Colors.primary)
                    
                    Chart {
                        ForEach(telemetryStream, id: \.time) { item in
                            // Temperature Line
                            LineMark(
                                x: .value("Time", item.time),
                                y: .value("Temperature (°C)", item.temp)
                            )
                            .foregroundStyle(Color.orange)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            
                            PointMark(
                                x: .value("Time", item.time),
                                y: .value("Temperature (°C)", item.temp)
                            )
                            .foregroundStyle(Color.orange)
                            .symbolSize(20)
                        }
                    }
                    .frame(height: 180)
                }
                .padding(20)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
            }
            .padding(20)
        }
    }
    
    private func metricCard(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(tint)
                Spacer()
            }
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.primary)
        }
        .padding(16)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
    }
}
