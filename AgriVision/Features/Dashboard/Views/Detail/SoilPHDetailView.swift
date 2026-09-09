import SwiftUI
import Charts

struct SoilPHDetailView: View {
    var phLevel: Double?
    var sensorStatus: String
    var cropType: String
    var readings: [SensorReading] = []
    
    private var validHistoricalPH: [(time: String, ph: Double)] {
        readings.compactMap { r in
            guard let val = r.ph else { return nil }
            return (time: r.time.formatted(date: .omitted, time: .shortened), ph: val)
        }
    }
    
    private var currentPH: Double {
        phLevel ?? 6.8
    }
    
    private var phAnalysis: (status: String, color: Color, description: String) {
        guard let ph = phLevel else {
            return ("Sensor Pending", .secondary, "Connect an RS485 soil probe or hardware node to stream real-time in-situ pH measurements.")
        }
        switch ph {
        case ..<5.5:
            return ("Strongly Acidic", .red, "Low pH inhibits Phosphorus and Magnesium absorption. Consider agricultural lime (calcium carbonate) application.")
        case 5.5..<6.2:
            return ("Moderately Acidic", .orange, "Suitable for acid-tolerant crops, but optimal nutrient uptake for \(cropType) is between 6.2 and 7.5.")
        case 6.2...7.5:
            return ("Optimal Neutral", Theme.Colors.primaryMedium, "Optimal pH range. Nitrogen, Phosphorus, and Potassium solubility and biological microbial activity are at peak.")
        case 7.6...8.3:
            return ("Moderately Alkaline", .blue, "Slightly elevated alkalinity. Iron and Zinc availability may decrease in calcareous soils.")
        default:
            return ("Strongly Alkaline", .purple, "High alkalinity causes severe micronutrient lock-out. Elemental sulfur or gypsum treatment may be required.")
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero pH Card
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Soil Acidity Index")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(phLevel.map { String(format: "%.2f", $0) } ?? "--")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.Colors.primary)
                        }
                        Spacer()
                        
                        Text(phAnalysis.status)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(phAnalysis.color)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(phAnalysis.color.opacity(0.14), in: Capsule())
                    }
                    
                    // Full pH Spectrum Bar
                    VStack(alignment: .leading, spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [.red, .orange, .yellow, Theme.Colors.primaryMedium, .blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 12)
                                
                                // Target range 6.0 - 7.5 indicator box
                                let minX = geo.size.width * CGFloat((6.0 - 4.0) / 5.0)
                                let maxX = geo.size.width * CGFloat((7.5 - 4.0) / 5.0)
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: max(10, maxX - minX), height: 16)
                                    .offset(x: minX, y: -2)
                                
                                // Needle
                                if phLevel != nil {
                                    let clamped = max(4.0, min(9.0, currentPH))
                                    let pinX = geo.size.width * CGFloat((clamped - 4.0) / 5.0)
                                    Capsule()
                                        .fill(Color.white)
                                        .frame(width: 4, height: 22)
                                        .shadow(color: .black.opacity(0.5), radius: 2)
                                        .offset(x: max(0, min(geo.size.width - 4, pinX)), y: -5)
                                }
                            }
                        }
                        .frame(height: 22)
                        
                        HStack {
                            Text("pH 4 (Acid)").font(.system(size: 10)).foregroundColor(.secondary)
                            Spacer()
                            Text("pH 6.5–7.5 (Target)").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.Colors.primaryMedium)
                            Spacer()
                            Text("pH 9 (Base)").font(.system(size: 10)).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(20)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
                
                // Optional Historical pH Timeline Chart
                if validHistoricalPH.count >= 2 {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("pH Timeline")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.Colors.primary)
                        
                        Chart {
                            ForEach(validHistoricalPH, id: \.time) { item in
                                LineMark(
                                    x: .value("Time", item.time),
                                    y: .value("pH", item.ph)
                                )
                                .foregroundStyle(Theme.Colors.primaryMedium)
                                .lineStyle(StrokeStyle(lineWidth: 2.5))
                                
                                PointMark(
                                    x: .value("Time", item.time),
                                    y: .value("pH", item.ph)
                                )
                                .foregroundStyle(Theme.Colors.primary)
                                .symbolSize(25)
                            }
                        }
                        .chartYScale(domain: 4...9)
                        .frame(height: 150)
                    }
                    .padding(20)
                    .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
                }
                
                // Nutrient Availability Impact Table
                VStack(alignment: .leading, spacing: 14) {
                    Text("Nutrient Absorption Impact")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.Colors.primary)
                    
                    VStack(spacing: 8) {
                        nutrientRow("Nitrogen (N)", "Available at pH 6.0–8.0", isGood: currentPH >= 6.0 && currentPH <= 8.0)
                        nutrientRow("Phosphorus (P)", "Available at pH 6.5–7.5 (Locked below 6.0)", isGood: currentPH >= 6.5 && currentPH <= 7.5)
                        nutrientRow("Potassium (K)", "Available at pH 6.0–8.5", isGood: currentPH >= 6.0 && currentPH <= 8.5)
                        nutrientRow("Micronutrients (Fe, Zn)", "Available at pH 5.5–7.0 (Locked above 7.8)", isGood: currentPH >= 5.5 && currentPH <= 7.0)
                    }
                }
                .padding(20)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
                
                // Agronomic Soil Guidance
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "flask.fill")
                            .foregroundColor(Theme.Colors.primaryMedium)
                        Text("Agronomic Soil Diagnosis")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.Colors.primary)
                    }
                    
                    Text(phAnalysis.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.primaryMedium.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Theme.Colors.primaryMedium.opacity(0.2), lineWidth: 1)
                )
            }
            .padding(20)
        }
    }
    
    private func nutrientRow(_ element: String, _ desc: String, isGood: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isGood ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(isGood ? Theme.Colors.primaryMedium : .orange)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(element).font(.system(size: 13, weight: .bold)).foregroundColor(Theme.Colors.primary)
                Text(desc).font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.black.opacity(0.02), in: RoundedRectangle(cornerRadius: 10))
    }
}
