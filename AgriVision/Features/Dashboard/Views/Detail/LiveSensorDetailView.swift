import SwiftUI
import Charts

struct LiveSensorDetailView: View {
    var reading: SensorReading?
    var sensorStatus: String
    var readings: [SensorReading] = []
    
    // Readings that carry at least one plottable metric, oldest first so both charts
    // read left-to-right in time (the API returns newest first). Values are left
    // optional on purpose — a missing metric leaves a gap in its own chart rather than
    // being back-filled with a stand-in number that would read as a real measurement.
    private var telemetryStream: [SensorReading] {
        let usable = readings
            .filter { $0.temperature != nil || $0.moisture != nil }
            .sorted { $0.time < $1.time }
        return usable.count >= 2 ? usable : []
    }

    private func hasSeries(_ value: (SensorReading) -> Double?) -> Bool {
        telemetryStream.contains { value($0) != nil }
    }

    // Both charts share one time axis so they can be read against each other, and so a series
    // that stops early (a metric going null) visibly ends short of the right edge instead of
    // being silently stretched to fill its own chart.
    private var timeDomain: ClosedRange<Date> {
        guard let first = telemetryStream.first?.time, let last = telemetryStream.last?.time, first < last else {
            let now = Date()
            return now.addingTimeInterval(-60)...now
        }
        return first...last
    }

    // AreaMark anchors its baseline at zero, which drags the y-domain down to 0 and flattens a
    // narrow band like soil temperature into a straight line. Deriving the domain from the data
    // (and starting the fill at its floor) keeps the real variation legible.
    private func paddedDomain(_ value: (SensorReading) -> Double?) -> ClosedRange<Double> {
        let values = telemetryStream.compactMap(value)
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        guard high > low else { return (low - 1)...(high + 1) }
        let padding = (high - low) * 0.15
        return (low - padding)...(high + padding)
    }

    // States the span actually plotted rather than implying a fixed window the data may not fill.
    private var windowLabel: String {
        guard let first = telemetryStream.first?.time, let last = telemetryStream.last?.time else {
            return "Live telemetry"
        }
        let minutes = max(1, Int(last.timeIntervalSince(first) / 60))
        return "Last \(minutes) min"
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
                
                // Temperature and moisture are different units on different scales, so they
                // get one chart each rather than a shared axis that would make their lines
                // falsely comparable.
                telemetryCard(title: "Soil Temperature", subtitle: windowLabel) {
                    telemetryChart(
                        tint: .orange,
                        label: "Temperature (°C)",
                        unit: "°C",
                        domain: paddedDomain { $0.temperature }
                    ) { $0.temperature }
                }

                telemetryCard(title: "Soil Moisture", subtitle: "\(windowLabel) · shaded band is the 30–50% target") {
                    // Fixed 0–100 rather than data-derived: moisture is a percentage of a known
                    // scale, so a low reading should look low instead of filling the frame.
                    telemetryChart(
                        tint: .cyan,
                        label: "Moisture (%)",
                        unit: "%",
                        domain: 0...100,
                        band: 30...50
                    ) { $0.moisture }
                }
            }
            .padding(20)
        }
    }
    
    private func telemetryCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.Colors.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            content()
        }
        .padding(20)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
    }

    // One series per chart, so the title identifies it and no legend is needed. A marker on
    // every sample would be an unreadable blob at ~240 points, so only the newest reading
    // carries a dot and a direct label — the axis and the line carry the rest.
    @ViewBuilder
    private func telemetryChart(
        tint: Color,
        label: String,
        unit: String,
        domain: ClosedRange<Double>,
        band: ClosedRange<Double>? = nil,
        value: @escaping (SensorReading) -> Double?
    ) -> some View {
        if hasSeries(value) {
            let points = telemetryStream.compactMap { reading -> (time: Date, value: Double)? in
                value(reading).map { (reading.time, $0) }
            }
            let latest = points.last

            Chart {
                if let band {
                    RectangleMark(
                        yStart: .value("Target low", band.lowerBound),
                        yEnd: .value("Target high", band.upperBound)
                    )
                    .foregroundStyle(tint.opacity(0.07))
                }

                ForEach(points, id: \.time) { point in
                    AreaMark(
                        x: .value("Time", point.time),
                        yStart: .value("Baseline", domain.lowerBound),
                        yEnd: .value(label, point.value)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [tint.opacity(0.22), tint.opacity(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Time", point.time),
                        y: .value(label, point.value)
                    )
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                }

                if let latest {
                    PointMark(
                        x: .value("Time", latest.time),
                        y: .value(label, latest.value)
                    )
                    .foregroundStyle(tint)
                    .symbolSize(70)
                    // 2px surface ring so the live dot stays legible over the area fill.
                    .annotation(position: .overlay) {
                        Circle()
                            .strokeBorder(Theme.Colors.surface, lineWidth: 2)
                            .frame(width: 12, height: 12)
                    }
                    .annotation(position: .top, spacing: 6) {
                        Text(String(format: "%.1f\(unit)", latest.value))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.Colors.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.surface.opacity(0.9), in: Capsule())
                    }
                }
            }
            .chartYScale(domain: domain)
            .chartXScale(domain: timeDomain)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                    AxisValueLabel()
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                    AxisValueLabel(format: .dateTime.hour().minute())
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary)
                }
            }
            .frame(height: 180)
            // Ease each new sample in so the line grows instead of snapping between polls.
            .animation(.easeInOut(duration: 0.35), value: latest?.time)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("Waiting for readings")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 180)
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
