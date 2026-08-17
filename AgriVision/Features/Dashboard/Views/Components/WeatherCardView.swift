import SwiftUI

struct WeatherCardView: View {
    var weather: FieldWeatherSoil.WeatherData?
    
    @State private var isOpen: Bool = false
    @State private var isIconVisible: Bool = false
    
    private var condition: WeatherCondition {
        WeatherCondition.from(description: weather?.current.description)
    }
    
    var tempString: String {
        if let temp = weather?.current.tempC {
            return "\(Int(round(temp)))°C"
        }
        return "--°C"
    }
    
    var rangeString: String {
        if let firstForecast = weather?.forecastDays.first,
           let maxTemp = firstForecast.tempMaxC,
           let minTemp = firstForecast.tempMinC {
            return "H: \(Int(round(maxTemp)))°  L: \(Int(round(minTemp)))°"
        }
        return "H: --°  L: --°"
    }
    
    var conditionString: String {
        return weather?.current.description?.capitalized ?? "Current Weather"
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            // MARK: - Layer 1: Liquid Aurora Multi-Stop Glass Base
            WeatherCardShape()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0x56/255.0, green: 0x8C/255.0, blue: 0x48/255.0).opacity(0.98), location: 0.0),  // Bright Sage Green
                            .init(color: Color(red: 0x3D/255.0, green: 0x6E/255.0, blue: 0x3F/255.0).opacity(0.98), location: 0.35), // Brand Emerald
                            .init(color: Color(red: 0x22/255.0, green: 0x4E/255.0, blue: 0x28/255.0), location: 0.72),               // Forest Jade
                            .init(color: Color(red: 0x13/255.0, green: 0x30/255.0, blue: 0x18/255.0), location: 1.0)                // Deep Glass Obsidian
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color(red: 0x1A/255.0, green: 0x3E/255.0, blue: 0x20/255.0).opacity(0.4), radius: 18, x: 4, y: 10)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 3)
            
            // MARK: - Layer 1.5: Luminous Liquid Aurora Glow
            WeatherCardShape()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0x86/255.0, green: 0xC8/255.0, blue: 0x6E/255.0).opacity(0.42),
                            Color(red: 0x56/255.0, green: 0x98/255.0, blue: 0x48/255.0).opacity(0.15),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
            
            // MARK: - Layer 2: Liquid Specular Light Overlay
            WeatherCardShape()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.35), location: 0.0),
                            .init(color: Color.white.opacity(0.10), location: 0.40),
                            .init(color: Color.clear, location: 0.75)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // MARK: - Layer 3: Specular Glass Edge Rim Highlight
            WeatherCardShape()
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.85), location: 0.0),
                            .init(color: Color.white.opacity(0.30), location: 0.45),
                            .init(color: Color.white.opacity(0.08), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.3
                )
            
            // MARK: - Content
            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                
                Text(tempString)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                
                Text(rangeString)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                
                HStack(alignment: .center) {
                    Text("Field Centroid")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                    
                    Spacer()
                    
                    Text(conditionString)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.24))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.4), lineWidth: 0.8)
                                )
                        )
                }
                .padding(.top, 10)
                
                if let humidity = weather?.current.humidity {
                    HStack(spacing: 4) {
                        Image(systemName: "humidity.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color.cyan)
                        Text("\(Int(round(humidity)))% Humidity")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.92))
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.leading, 20)
            .padding(.trailing, 20)
            .padding(.bottom, 18)
            
            // MARK: - Floating 3D Weather Icon (Pops up after 1 second)
            GeometryReader { geo in
                Image(systemName: condition.iconName)
                    .symbolRenderingMode(.multicolor)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 85, height: 85)
                    .shadow(color: Color.black.opacity(isIconVisible ? 0.28 : 0.0), radius: 10, x: 2, y: 6)
                    .position(x: geo.size.width - 20, y: 45)
                    .scaleEffect(isIconVisible ? 1.0 : 0.001)
                    .opacity(isIconVisible ? 1.0 : 0.0)
            }
        }
        .frame(height: 180)
        // 3D Door / Window Opening Animation coming from BEHIND the screen
        .rotation3DEffect(
            .degrees(isOpen ? 0 : 55),
            axis: (x: 0, y: 1, z: 0),
            anchor: .leading,
            perspective: 0.5
        )
        .scaleEffect(isOpen ? 1.0 : 0.88, anchor: .leading)
        .offset(x: isOpen ? 0 : -35)
        .opacity(isOpen ? 1.0 : 0.05)
        .animation(.spring(response: 1.35, dampingFraction: 0.82, blendDuration: 0.3), value: isOpen)
        .onAppear {
            // 1. Card swings open first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isOpen = true
            }
            // 2. Weather icon pops up with a bouncy spring after 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.spring(response: 0.65, dampingFraction: 0.62, blendDuration: 0.2)) {
                    isIconVisible = true
                }
            }
        }
    }
}

// MARK: - Weather Condition Classification
private enum WeatherCondition {
    case clearSky
    case partlyCloudy
    case cloudy
    case rainy
    case thunderstorm
    case snowy
    case foggy
    
    static func from(description: String?) -> WeatherCondition {
        guard let desc = description?.lowercased() else { return .partlyCloudy }
        if desc.contains("thunder") || desc.contains("storm") || desc.contains("lightning") {
            return .thunderstorm
        } else if desc.contains("rain") || desc.contains("drizzle") || desc.contains("shower") {
            return .rainy
        } else if desc.contains("snow") || desc.contains("sleet") || desc.contains("ice") || desc.contains("hail") {
            return .snowy
        } else if desc.contains("fog") || desc.contains("mist") || desc.contains("haze") || desc.contains("smoke") {
            return .foggy
        } else if desc.contains("clear") || desc.contains("sun") {
            return .clearSky
        } else if desc.contains("cloud") || desc.contains("overcast") {
            return (desc.contains("few") || desc.contains("scattered") || desc.contains("part")) ? .partlyCloudy : .cloudy
        }
        return .partlyCloudy
    }
    
    var iconName: String {
        switch self {
        case .clearSky: return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy: return "cloud.fill"
        case .rainy: return "cloud.sun.rain.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        case .snowy: return "snowflake"
        case .foggy: return "cloud.fog.fill"
        }
    }
}

