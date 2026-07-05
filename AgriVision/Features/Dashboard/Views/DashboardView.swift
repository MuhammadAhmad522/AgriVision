import SwiftUI
import Charts

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    // State for the draggable bottom sheet
    @State private var sheetHeight: CGFloat = 300
    @State private var startingSheetHeight: CGFloat = 300
    
    var body: some View {
        TabView {
            ZStack(alignment: .bottom) {
                // Background
                Image("bg-image")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        // Fixed Background Elements
                        VStack(alignment: .leading, spacing: 12) {
                            // Top Custom Navigation Bar
                            DashboardHeaderView(userName: viewModel.userName ?? "Ahmad", profileImageURL: viewModel.profileImageURL, profileInitial: viewModel.profileInitial)
                                .padding(.top, 65) // Increased padding to move elements down away from notch
                            
                            // Weather & Field Health Section
                            HStack(alignment: .center, spacing: 0) {
                                WeatherCardView(weather: viewModel.weatherSoil?.weather)
                                    .frame(width: geo.size.width * 0.55)
                                
                                Spacer()
                                
                                HealthCardView(healthScore: viewModel.healthSummary?.score ?? 0.75, cropType: viewModel.currentCropType)
                                    .padding(.trailing, 20)
                            }
                            
                            // Three Metrics Cards
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    MoistureCardView(moisture: Int((viewModel.weatherSoil?.soil.moisture ?? 0.35) * 100))
                                    PHLevelCardView(phLevel: 6.5)
                                    NDVICardView(ndvi: viewModel.healthSummary?.score ?? 0.86)
                                    SoilTempCardView(surfaceTemp: viewModel.weatherSoil?.soil.surfaceTempC ?? 22.0, depthTemp: viewModel.weatherSoil?.soil.depthTempC ?? 19.0)
                                }
                                .padding(.horizontal, 20)
                            }
                            
                            Spacer()
                        }
                        // Bottom Alerts Sheet (Draggable with snapping)
                        AlertsBottomSheet(viewModel: viewModel)
                            .frame(height: sheetHeight)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newHeight = startingSheetHeight - value.translation.height
                                        // Keep height within bounds using smooth clamping
                                        sheetHeight = max(300, min(newHeight, geo.size.height * 0.85))
                                    }
                                    .onEnded { value in
                                        let predictedEndLocation = value.predictedEndLocation.y
                                        let translation = value.translation.height
                                        
                                        withAnimation(.interpolatingSpring(stiffness: 300.0, damping: 30.0, initialVelocity: 10.0)) {
                                            // Snap logic based on drag direction and speed
                                            if translation < -50 || predictedEndLocation < 0 {
                                                sheetHeight = geo.size.height * 0.85 // Full open
                                            } else if translation > 50 || predictedEndLocation > 0 {
                                                sheetHeight = 300 // Collapsed
                                            } else {
                                                // Snap to nearest
                                                if abs(sheetHeight - 300) < abs(sheetHeight - geo.size.height * 0.85) {
                                                    sheetHeight = 300
                                                } else {
                                                    sheetHeight = geo.size.height * 0.85
                                                }
                                            }
                                            startingSheetHeight = sheetHeight
                                        }
                                    }
                            )
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            
            Text("Fields View Placeholder")
                .tabItem {
                    Label("Fields", systemImage: "leaf.fill")
                }
            
            Text("Settings View Placeholder")
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(AppColors.mediumGreen)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.refreshData()
        }
    }
}

// MARK: - Components

struct DashboardHeaderView: View {
    var userName: String
    var profileImageURL: URL?
    var profileInitial: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                // Location Pill
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(AppColors.charcoalGreen)
                    Text("Lahore, Punjab")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppColors.charcoalGreen)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                
                Spacer()
                
                // Avatar
                if let url = profileImageURL {
                    // Google User Profile Image
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image.resizable()
                                 .aspectRatio(contentMode: .fill)
                        case .failure:
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundColor(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 2)
                    
                } else {
                    // Email User - Last Name Initial
                    ZStack {
                        Circle()
                            .fill(AppColors.limeGreen)
                        
                        Text(profileInitial)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(width: 40, height: 40)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 2)
                }
            }
            .padding(.horizontal, 18)
            
            HStack {
                Text("Hi, \(userName)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.charcoalGreen)
                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }
}

// Custom slanted shape sticking to the left
struct WeatherCardShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = 30
        let slantDrop: CGFloat = 40 // How far down the right side drops
        
        // Start top-left (flush with screen)
        path.move(to: CGPoint(x: 0, y: 0))
        
        // Line down to top-right slanted point
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: slantDrop))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: slantDrop + cornerRadius), control: CGPoint(x: rect.maxX, y: slantDrop))
        
        // Right edge down
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        
        // Bottom edge left to edge of screen
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        
        path.closeSubpath()
        return path
    }
}

struct WeatherCardView: View {
    var weather: FieldWeatherSoil.WeatherData?
    
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
            return "H:\(Int(round(maxTemp)))° L:\(Int(round(minTemp)))°"
        }
        return "H:--° L:--°"
    }
    
    var conditionString: String {
        return weather?.current.description?.capitalized ?? "Loading..."
    }
    
    var iconName: String {
        guard let desc = weather?.current.description?.lowercased() else {
            return "cloud.sun.fill"
        }
        if desc.contains("rain") || desc.contains("drizzle") || desc.contains("shower") {
            return "cloud.sun.rain.fill"
        } else if desc.contains("snow") || desc.contains("ice") {
            return "snowflake"
        } else if desc.contains("cloud") {
            return "cloud.fill"
        } else if desc.contains("clear") || desc.contains("sun") {
            return "sun.max.fill"
        } else if desc.contains("storm") || desc.contains("thunder") {
            return "cloud.bolt.rain.fill"
        }
        return "cloud.sun.fill"
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            WeatherCardShape()
                .fill(
                    LinearGradient(
                        colors: [AppColors.limeGreen, AppColors.charcoalGreen],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.15), radius: 10, x: 5, y: 5)
            
            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                Text(tempString)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white)
                Text(rangeString)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
                
                HStack {
                    Text("Field Centroid")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text(conditionString)
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.top, 12)
            }
            .padding(.leading, 20)
            .padding(.trailing, 20)
            .padding(.bottom, 20)
            
            // 3D Weather Icons Layout mapping
            GeometryReader { geo in
                Image(systemName: iconName)
                    .renderingMode(.original)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 90, height: 90)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 5, y: 10)
                    .position(x: geo.size.width - 15, y: 40)
            }
        }
        .frame(height: 180)
    }
}

struct SoilTempCardView: View {
    var surfaceTemp: Double
    var depthTemp: Double
    
    var body: some View {
        LiquidGlassCard {
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "thermometer.medium")
                        .foregroundColor(.orange)
                    Text("Soil Temp")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.charcoalGreen)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Surface")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.gray)
                            Text(String(format: "%.1f°C", surfaceTemp))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(AppColors.charcoalGreen)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("10cm Depth")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.gray)
                            Text(String(format: "%.1f°C", depthTemp))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(AppColors.charcoalGreen)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                
                Spacer()
                
                Text("Satellite Ground Scan")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.bottom, 12)
            }
        }
        .frame(width: 140, height: 164)
    }
}

struct HealthCardView: View {
    var healthScore: Double
    var cropType: String
    
    var cropImageName: String {
        switch cropType.lowercased() {
        case "wheat": return "wheat"
        case "rice": return "rice"
        case "sugarcane": return "sugarcane"
        default: return "leaf.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .center) {
            if ["wheat", "rice", "sugarcane"].contains(cropType.lowercased()) {
                Image(cropImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 110, height: 110)
            } else {
                Image(systemName: "leaf.fill") // Fallback
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 110, height: 110)
                    .foregroundColor(AppColors.mediumGreen)
            }
            
            Text("\(cropType.capitalized) Field")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppColors.charcoalGreen)
                .padding(.top, 4)
            
            ZStack {
                Circle()
                    .stroke(AppColors.limeGreen.opacity(0.3), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: CGFloat(healthScore))
                    .stroke(AppColors.mediumGreen, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(healthScore * 100))%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.charcoalGreen)
            }
            .frame(width: 80, height: 80)
            .padding(.top, 8)
            
            Text("Health")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppColors.charcoalGreen)
                .padding(.top, 4)
        }
    }
}

// MARK: - Metric Cards

struct LiquidGlassCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.white.opacity(0.8))
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 8)
            
            content
                .frame(width: 140, height: 164)
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        }
        .frame(width: 140, height: 164)
    }
}

struct MoistureCardView: View {
    var moisture: Int
    var body: some View {
        LiquidGlassCard {
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .foregroundColor(.cyan) // matched light blue
                        .shadow(radius: 1)
                    Text("Soil Moisture")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.charcoalGreen)
                    Spacer()
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.mediumGreen)
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
                            .trim(from: 0.5, to: 0.5 + (0.5 * CGFloat(moisture)/100))
                            .stroke(AppColors.mediumGreen, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .padding(4)
                    }
                    .frame(width: 80, height: 80)
                    .frame(height: 40, alignment: .top) // Clip perfectly to the top half
                    .clipped()
                    
                    Text("\(moisture)%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.charcoalGreen)
                        .padding(.bottom, -2)
                }
                .padding(.top, 10)
                
                Spacer(minLength: 0)
                
                Text("Optimal Value: 30-50")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.mediumGreen)
                
                Spacer(minLength: 0)
                
                if #available(iOS 16.0, *) {
                    let mockData: [Double] = [40, 42, 45, 50, 48, 55, 60, Double(moisture)]
                    Chart {
                        ForEach(0..<mockData.count, id: \.self) { index in
                            LineMark(
                                x: .value("Time", index),
                                y: .value("Moisture", mockData[index])
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(AppColors.mediumGreen)
                            
                            AreaMark(
                                x: .value("Time", index),
                                y: .value("Moisture", mockData[index])
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppColors.limeGreen.opacity(0.3), AppColors.limeGreen.opacity(0.0)],
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

struct PHLevelCardView: View {
    var phLevel: Double
    var body: some View {
        LiquidGlassCard {
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "flask.fill") // Using standard flask icon
                        .foregroundColor(AppColors.limeGreen)
                    Text("Soil pH Level")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.charcoalGreen)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)
                
                Spacer()
                
                VStack(spacing: 4) {
                    Gauge(value: phLevel, in: 4...9) {
                        EmptyView()
                    } currentValueLabel: {
                        Text(String(format: "%.1f", phLevel))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.charcoalGreen)
                    }
                    .gaugeStyle(.linearCapacity)
                    .tint(Gradient(colors: [.red, .orange, .yellow, .green, .blue, .indigo, .purple]))
                }
                .padding(.horizontal, 16)
                
                Spacer()
                
                Text("Neutral (Ideal for rice)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.mediumGreen)
                    .padding(.bottom, 22)
            }
        }
    }
}

struct NDVICardView: View {
    var ndvi: Double
    var body: some View {
        LiquidGlassCard {
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "map.fill")
                        .foregroundColor(AppColors.limeGreen)
                    Text("NDVI")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.charcoalGreen)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)
                
                Spacer()
                
                VStack(spacing: 8) {
                    Text(String(format: "%.2f", ndvi))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(AppColors.charcoalGreen)
                    
                    Gauge(value: ndvi, in: 0...1) {
                        EmptyView()
                    }
                    .gaugeStyle(.linearCapacity)
                    .tint(Gradient(colors: [.orange, .yellow, .green]))
                }
                .padding(.horizontal, 16)
                
                Spacer()
                
                Text("Healthy")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.mediumGreen)
                    .padding(.bottom, 22)
            }
        }
    }
}

// MARK: - Bottom Alerts Card

struct AlertsBottomSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        ZStack(alignment: .top) {
            // Glass Background covering full width
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .light)
                .shadow(color: .black.opacity(0.1), radius: 20, y: -5)
                .padding(.bottom, -100) // Extend beyond the bottom frame to hide bottom corners
            
            VStack(spacing: 0) {
                // Grabber
                Capsule()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                
                List {
                    Section {
                        AlertRow(iconName: "exclamationmark.circle.fill", iconColor: .orange, text: "Water level is low in mango farm")
                        AlertRow(iconName: "checkmark.circle.fill", iconColor: .green, text: "Strawberries are ready to harvest")
                        AlertRow(iconName: "light.beacon.max.fill", iconColor: .red, text: "Locusts are expected to pay a visit tomorrow")
                        AlertRow(iconName: "checkmark.circle.fill", iconColor: .green, text: "Strawberries are ready to harvest")
                    }
                    .listRowBackground(Color.gray.opacity(0.16))
                    
                    // Extra space at bottom to scroll past the floating tab bar if fully expanded
                    Spacer().frame(height: 100)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

struct AlertRow: View {
    var iconName: String
    var iconColor: Color
    var text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.05), radius: 5)
            
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.black)
                .lineLimit(1)
            
            Spacer()
        }
        .frame(height: 60)
    }
}



// MARK: - Preview

#Preview("Dashboard - Wheat") {
    NavigationStack {
        DashboardView(viewModel: DashboardViewModel(dataService: MockAgriDataRepository(mockCropType: "Wheat"), authService: MockAuthService(isLoggedIn: true)))
    }
}

#Preview("Dashboard - Rice") {
    NavigationStack {
        DashboardView(viewModel: DashboardViewModel(dataService: MockAgriDataRepository(mockCropType: "Rice"), authService: MockAuthService(isLoggedIn: true)))
    }
}

#Preview("Dashboard - Sugarcane") {
    NavigationStack {
        DashboardView(viewModel: DashboardViewModel(dataService: MockAgriDataRepository(mockCropType: "Sugarcane"), authService: MockAuthService(isLoggedIn: true)))
    }
}
