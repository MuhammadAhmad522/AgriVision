import SwiftUI
import Charts
import UIKit

private enum DashboardLayout {
    static let collapsedAlertsSheetHeight: CGFloat = 250
}

struct DashboardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @State private var selectedTab: DashboardTab = .home
    
    // State for the draggable bottom sheet
    @State private var sheetHeight: CGFloat = DashboardLayout.collapsedAlertsSheetHeight
    @State private var startingSheetHeight: CGFloat = DashboardLayout.collapsedAlertsSheetHeight
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeometryReader { pageGeometry in
                ScrollView(.vertical) {
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
                            DashboardHeaderView(
                                userName: viewModel.userName ?? "Farmer",
                                location: viewModel.activeField?.name ?? "No active field",
                                profileImageURL: viewModel.profileImageURL,
                                profileInitial: viewModel.profileInitial
                            )
                                .padding(.top, 65) // Increased padding to move elements down away from notch

                            if !viewModel.dataAvailability.isEmpty {
                                DataAvailabilityCard(items: viewModel.dataAvailability) {
                                    Task { await viewModel.requestDataRefresh() }
                                }
                                .padding(.horizontal, 18)
                            }
                            
                            // Weather & Field Health Section
                            HStack(alignment: .center, spacing: 0) {
                                WeatherCardView(weather: viewModel.weatherSoil?.weather)
                                    .frame(width: geo.size.width * 0.55)
                                
                                Spacer()
                                
                                HealthCardView(
                                    healthScore: viewModel.healthSummary?.score,
                                    cropType: viewModel.currentCropType
                                )
                                    .padding(.trailing, 20)
                            }
                            
                            // Three Metrics Cards
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    MoistureCardView(moisture: viewModel.weatherSoil?.soil.moisture.map { Int($0 * 100) })
                                    PHLevelCardView(phLevel: viewModel.readings.first?.ph, sensorStatus: viewModel.sensorStatus)
                                    SensorLiveCardView(reading: viewModel.readings.first, sensorStatus: viewModel.sensorStatus)
                                    NDVICardView(ndvi: viewModel.satellite?.data?.statistics?["ndvi"]?.mean ?? viewModel.healthSummary?.score)
                                    VegetationIndicesCardView(statistics: viewModel.satellite?.data?.statistics)
                                    UVIndexCardView(snapshot: viewModel.uvi?.data, status: viewModel.uvi?.status)
                                    SatelliteQualityCardView(snapshot: viewModel.satellite?.data)
                                    ForecastCardView(days: viewModel.weatherSoil?.weather.forecastDays ?? [])
                                    SensorChemistryCardView(reading: viewModel.readings.first, sensorStatus: viewModel.sensorStatus)
                                    SatelliteImageCardView(imageData: viewModel.truecolorImageData)
                                    SoilTempCardView(surfaceTemp: viewModel.weatherSoil?.soil.surfaceTempC, depthTemp: viewModel.weatherSoil?.soil.depthTempC)
                                }
                                .padding(.horizontal, 20)
                            }
                            
                            Spacer()
                        }
                        // Bottom Alerts Sheet (Draggable with snapping)
                        AlertsBottomSheet(
                            viewModel: viewModel,
                            onShowAll: {
                                withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                    sheetHeight = geo.size.height * 0.85
                                    startingSheetHeight = sheetHeight
                                }
                            }
                        )
                            .id(viewModel.fieldSessionStore.activeFieldId)
                            .frame(height: sheetHeight)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newHeight = startingSheetHeight - value.translation.height
                                        // Keep height within bounds using smooth clamping
                                        sheetHeight = max(DashboardLayout.collapsedAlertsSheetHeight, min(newHeight, geo.size.height * 0.85))
                                    }
                                    .onEnded { value in
                                        let predictedEndLocation = value.predictedEndLocation.y
                                        let translation = value.translation.height
                                        
                                        withAnimation(.interpolatingSpring(stiffness: 300.0, damping: 30.0, initialVelocity: 10.0)) {
                                            // Snap logic based on drag direction and speed
                                            if translation < -50 || predictedEndLocation < 0 {
                                                sheetHeight = geo.size.height * 0.85 // Full open
                                            } else if translation > 50 || predictedEndLocation > 0 {
                                                sheetHeight = DashboardLayout.collapsedAlertsSheetHeight
                                            } else {
                                                // Snap to nearest
                                                if abs(sheetHeight - DashboardLayout.collapsedAlertsSheetHeight) < abs(sheetHeight - geo.size.height * 0.85) {
                                                    sheetHeight = DashboardLayout.collapsedAlertsSheetHeight
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
                    .frame(width: pageGeometry.size.width, height: pageGeometry.size.height)
                }
                .scrollIndicators(.hidden)
                .refreshable { await viewModel.refreshData() }
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(DashboardTab.home)
            
            FieldsView(
                fieldStore: viewModel.fieldSessionStore,
                satellite: viewModel.satellite,
                satelliteImageData: viewModel.satelliteImageData,
                sensorCount: viewModel.sensorCount,
                snapshotFieldId: viewModel.loadedFieldId,
                isLoadingSnapshot: viewModel.isLoading,
                profileImageURL: viewModel.profileImageURL,
                profileInitial: viewModel.profileInitial,
                onAddField: viewModel.addField
            )
                .tabItem {
                    Label("Fields", systemImage: "leaf.fill")
                }
                .tag(DashboardTab.fields)
            
            SettingsView(
                viewModel: settingsViewModel,
                onBack: { selectedTab = .home }
            )
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(DashboardTab.settings)
        }
        .tint(AppColors.mediumGreen)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await viewModel.pollUntilCancelled()
        }
        .task(id: viewModel.fieldSessionStore.activeFieldId) {
            await viewModel.refreshData()
        }
        .onChange(of: viewModel.fieldSessionStore.activeFieldId) {
            sheetHeight = DashboardLayout.collapsedAlertsSheetHeight
            startingSheetHeight = DashboardLayout.collapsedAlertsSheetHeight
        }
        .overlay(alignment: .top) {
            if let error = viewModel.errorMessage {
                ToastView(message: error, type: .error).padding(.top, 56).padding(.horizontal)
            } else if let success = viewModel.successMessage {
                ToastView(message: success, type: .success).padding(.top, 56).padding(.horizontal)
            }
        }
    }
}

struct DataAvailabilityCard: View {
    let items: [DataAvailabilityItem]
    let onRetry: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(AppColors.mediumGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Data availability").font(.subheadline.bold())
                        Text("\(items.count) source\(items.count == 1 ? "" : "s") still preparing or unavailable")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down").rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .foregroundStyle(AppColors.charcoalGreen)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(color(for: item.status)).frame(width: 8, height: 8).padding(.top, 5)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(item.title) · \(label(for: item.status))").font(.caption.bold())
                            if let message = item.message { Text(message).font(.caption2).foregroundStyle(.secondary) }
                            if let date = item.lastUpdated { Text("Updated \(date.formatted(.relative(presentation: .named)))").font(.caption2).foregroundStyle(.secondary) }
                        }
                    }
                }
                if items.contains(where: \.retryable) {
                    Button(action: onRetry) { Label("Refresh available sources", systemImage: "arrow.clockwise") }
                        .font(.caption.bold()).foregroundStyle(AppColors.mediumGreen)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppColors.limeGreen.opacity(0.5)))
    }

    private func label(for status: DataSourceStatus) -> String {
        switch status {
        case .available: return "Available"
        case .pending: return "Preparing"
        case .stale: return "Needs refresh"
        case .unavailable: return "Unavailable"
        case .unsupported: return "Not supported"
        case .notConfigured: return "Not connected"
        }
    }

    private func color(for status: DataSourceStatus) -> Color {
        switch status {
        case .pending, .notConfigured, .unsupported: return AppColors.mediumGreen
        case .stale: return AppColors.warningOrange
        case .unavailable: return .red
        case .available: return AppColors.limeGreen
        }
    }
}

private enum DashboardTab: Hashable {
    case home
    case fields
    case settings
}

// MARK: - Components

struct DashboardHeaderView: View {
    var userName: String
    var location: String
    var profileImageURL: URL?
    var profileInitial: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                // Location Pill
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(AppColors.charcoalGreen)
                    Text(location)
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
                if let humidity = weather?.current.humidity {
                    Label("\(Int(round(humidity)))% humidity", systemImage: "humidity.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
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
    var surfaceTemp: Double?
    var depthTemp: Double?
    
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
                            Text(surfaceTemp.map { String(format: "%.1f°C", $0) } ?? "--")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(AppColors.charcoalGreen)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("10cm Depth")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.gray)
                            Text(depthTemp.map { String(format: "%.1f°C", $0) } ?? "--")
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
    var healthScore: Double?
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
                    .trim(from: 0, to: CGFloat(healthScore ?? 0))
                    .stroke(AppColors.mediumGreen, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(healthScore.map { "\(Int($0 * 100))%" } ?? "--")
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
    var moisture: Int?
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
                            .trim(from: 0.5, to: 0.5 + (0.5 * CGFloat(moisture ?? 0) / 100))
                            .stroke(AppColors.mediumGreen, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .padding(4)
                    }
                    .frame(width: 80, height: 80)
                    .frame(height: 40, alignment: .top) // Clip perfectly to the top half
                    .clipped()
                    
                    Text(moisture.map { "\($0)%" } ?? "--")
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
                    let chartData: [Double] = moisture.map { [Double($0)] } ?? []
                    Chart {
                        ForEach(0..<chartData.count, id: \.self) { index in
                            LineMark(
                                x: .value("Time", index),
                                y: .value("Moisture", chartData[index])
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(AppColors.mediumGreen)
                            
                            AreaMark(
                                x: .value("Time", index),
                                y: .value("Moisture", chartData[index])
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
    var phLevel: Double?
    var sensorStatus: String
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
                    Gauge(value: phLevel ?? 4, in: 4...9) {
                        EmptyView()
                    } currentValueLabel: {
                        Text(phLevel.map { String(format: "%.1f", $0) } ?? "--")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.charcoalGreen)
                    }
                    .gaugeStyle(.linearCapacity)
                    .tint(Gradient(colors: [.red, .orange, .yellow, .green, .blue, .indigo, .purple]))
                }
                .padding(.horizontal, 16)
                
                Spacer()
                
                Text(phLevel != nil ? "Live sensor reading" : (sensorStatus == "not_configured" ? "Optional sensor not connected" : "Waiting for sensor data"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.mediumGreen)
                    .padding(.bottom, 22)
            }
        }
    }
}

struct NDVICardView: View {
    var ndvi: Double?
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
                    Text(ndvi.map { String(format: "%.2f", $0) } ?? "--")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(AppColors.charcoalGreen)
                    
                    Gauge(value: ndvi ?? 0, in: 0...1) {
                        EmptyView()
                    }
                    .gaugeStyle(.linearCapacity)
                    .tint(Gradient(colors: [.orange, .yellow, .green]))
                }
                .padding(.horizontal, 16)
                
                Spacer()
                
                Text(ndvi == nil ? "Satellite pending" : "Latest acquisition")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.mediumGreen)
                    .padding(.bottom, 22)
            }
        }
    }
}

struct SensorLiveCardView: View {
    let reading: SensorReading?
    let sensorStatus: String

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Live Sensor", systemImage: "sensor.tag.radiowaves.forward.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.charcoalGreen)
                Spacer()
                metric("Temperature", reading?.temperature.map { String(format: "%.1f°C", $0) } ?? "--")
                metric("Moisture", reading?.moisture.map { String(format: "%.0f%%", $0) } ?? "--")
                Spacer()
                Text(reading.map { "Updated \($0.time.formatted(.relative(presentation: .named)))" } ?? statusText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(reading == nil ? .secondary : AppColors.mediumGreen)
            }
            .padding(16)
        }
    }

    private var statusText: String {
        sensorStatus == "not_configured" ? "No sensor paired" : "Waiting for readings"
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 18, weight: .bold)).foregroundStyle(AppColors.charcoalGreen)
        }
    }
}

struct VegetationIndicesCardView: View {
    let statistics: [String: VegetationStatistics]?

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 9) {
                Label("Vegetation", systemImage: "leaf.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.charcoalGreen)
                Spacer()
                indexRow("NDVI", statistics?["ndvi"]?.mean)
                indexRow("EVI", statistics?["evi"]?.mean)
                indexRow("EVI2", statistics?["evi2"]?.mean)
                Spacer()
                Text("Scene averages").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            }
            .padding(16)
        }
    }

    private func indexRow(_ name: String, _ value: Double?) -> some View {
        HStack {
            Text(name).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            Spacer()
            Text(value.map { String(format: "%.3f", $0) } ?? "--")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppColors.charcoalGreen)
        }
    }
}

struct UVIndexCardView: View {
    let snapshot: UVISnapshot?
    let status: String?

    var body: some View {
        LiquidGlassCard {
            VStack(spacing: 10) {
                HStack {
                    Label("UV Index", systemImage: "sun.max.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.charcoalGreen)
                    Spacer()
                }
                Spacer()
                Text(snapshot?.uvi.map { String(format: "%.1f", $0) } ?? "--")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(uvColor)
                Text(riskLabel).font(.system(size: 12, weight: .bold)).foregroundStyle(uvColor)
                Spacer()
                Text(snapshot == nil ? (status?.capitalized ?? "Pending") : "Live AgroMonitoring")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            }
            .padding(16)
        }
    }

    private var riskLabel: String {
        guard let value = snapshot?.uvi else { return "No reading" }
        switch value {
        case ..<3: return "Low"
        case ..<6: return "Moderate"
        case ..<8: return "High"
        case ..<11: return "Very high"
        default: return "Extreme"
        }
    }

    private var uvColor: Color {
        guard let value = snapshot?.uvi else { return .secondary }
        if value < 3 { return .green }
        if value < 6 { return .yellow }
        if value < 8 { return .orange }
        return .red
    }
}

struct SatelliteQualityCardView: View {
    let snapshot: SatelliteSnapshot?

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Scene Quality", systemImage: "cloud.sun.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.charcoalGreen)
                Spacer()
                qualityRow("Cloud", snapshot?.cloudPercent)
                qualityRow("Coverage", snapshot?.coveragePercent)
                Spacer()
                Text(snapshot.map { "Captured \($0.acquiredAt.formatted(date: .abbreviated, time: .omitted))" } ?? "Satellite pending")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            }
            .padding(16)
        }
    }

    private func qualityRow(_ name: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(name).font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Text(value.map { String(format: "%.0f%%", $0) } ?? "--").font(.system(size: 13, weight: .bold))
            }
            ProgressView(value: min(max(value ?? 0, 0), 100), total: 100).tint(AppColors.mediumGreen)
        }
    }
}

struct ForecastCardView: View {
    let days: [FieldWeatherSoil.ForecastDay]

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 7) {
                Label("Forecast", systemImage: "calendar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.charcoalGreen)
                Spacer()
                ForEach(Array(days.prefix(3))) { day in
                    HStack(spacing: 5) {
                        Text(shortDate(day.date)).frame(width: 34, alignment: .leading)
                        Text(day.tempMaxC.map { "\(Int(round($0)))°" } ?? "--")
                        Spacer()
                        Label(day.rainMm.map { String(format: "%.1f", $0) } ?? "--", systemImage: "drop.fill")
                            .foregroundStyle(.cyan)
                    }
                    .font(.system(size: 10, weight: .semibold))
                }
                Spacer()
                Text(days.isEmpty ? "Weather pending" : "Rain shown in mm")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            }
            .padding(16)
        }
    }

    private func shortDate(_ value: String) -> String {
        value.count >= 10 ? String(value.suffix(5)) : value
    }
}

struct SensorChemistryCardView: View {
    let reading: SensorReading?
    let sensorStatus: String

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 7) {
                Label("Soil Chemistry", systemImage: "testtube.2")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.charcoalGreen)
                Spacer()
                row("EC", reading?.ec, suffix: "")
                row("N", reading?.npk_n, suffix: "")
                row("P", reading?.npk_p, suffix: "")
                row("K", reading?.npk_k, suffix: "")
                Spacer()
                Text(hasChemistry ? "Live sensor values" : (sensorStatus == "not_configured" ? "No sensor paired" : "Probe is not reporting these channels"))
                    .font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
            }
            .padding(16)
        }
    }

    private var hasChemistry: Bool {
        [reading?.ec, reading?.npk_n, reading?.npk_p, reading?.npk_k].contains { $0 != nil }
    }

    private func row(_ label: String, _ value: Double?, suffix: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value.map { String(format: "%.1f%@", $0, suffix) } ?? "--").fontWeight(.bold)
        }
        .font(.system(size: 10))
    }
}

struct SatelliteImageCardView: View {
    let imageData: Data?

    var body: some View {
        LiquidGlassCard {
            ZStack(alignment: .bottomLeading) {
                if let imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Color.gray.opacity(0.12)
                    Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
                }
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 2) {
                    Text("True color").font(.system(size: 13, weight: .bold))
                    Text(imageData == nil ? "Image pending" : "Latest satellite scene").font(.system(size: 10))
                }
                .foregroundStyle(.white)
                .padding(14)
            }
        }
    }
}

// MARK: - Bottom Alerts Card

struct AlertsBottomSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    let onShowAll: () -> Void
    
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
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("AI Field Advisor")
                                    .font(.headline)
                                Text(advisorSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !viewModel.recommendations.isEmpty {
                                Button(action: onShowAll) {
                                    Label(
                                        "View all \(viewModel.recommendations.count)",
                                        systemImage: "arrow.up.left.and.arrow.down.right"
                                    )
                                }
                                .font(.caption.bold())
                            }
                        }
                        HStack {
                            Button { Task { await viewModel.refreshRecommendations() } } label: {
                                Label("Refresh advice", systemImage: "arrow.clockwise")
                            }
                            .disabled(viewModel.isRefreshingAI)
                            Spacer()
                            Button(action: viewModel.openChat) {
                                Label("Ask AI", systemImage: "sparkles")
                            }
                        }
                        if viewModel.recommendations.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    if viewModel.advisorStatus == "pending" {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                    }
                                    Text(
                                        viewModel.isLoading
                                            ? "Loading recommendations…"
                                            : (viewModel.advisorMessage ?? "AI is preparing the first field assessment.")
                                    )
                                }
                                .foregroundStyle(.secondary)
                                if let quality = viewModel.advisorDataQuality {
                                    Text("Evidence quality: \(quality.capitalized)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if viewModel.advisorStatus == "unavailable" || viewModel.advisorStatus == "stale" {
                                    Button("Retry analysis") {
                                        Task { await viewModel.refreshRecommendations() }
                                    }
                                    .font(.caption.bold())
                                }
                            }
                        } else {
                            if viewModel.advisorStatus == "stale" || viewModel.advisorStatus == "unavailable" {
                                Label(
                                    viewModel.advisorMessage ?? "Showing the last successful advice while AI retries.",
                                    systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90"
                                )
                                .font(.caption)
                                .foregroundStyle(.orange)
                            }
                            if viewModel.recommendations.count > 1 {
                                Text("Scroll or tap View all to read every recommendation for this field.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(viewModel.recommendations) { recommendation in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(recommendation.icon)
                                        Text(recommendation.category).font(.headline)
                                        Spacer()
                                        Text(recommendation.priority.capitalized).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Text(recommendation.advice).font(.subheadline)
                                    if let rationale = recommendation.rationale {
                                        Text(rationale).font(.caption).foregroundStyle(.secondary)
                                    }
                                    if recommendation.requiresExpertConfirmation {
                                        Label("Expert confirmation required", systemImage: "person.badge.shield.checkmark")
                                            .font(.caption.bold()).foregroundStyle(.orange)
                                    }
                                    if recommendation.status == "pending" {
                                        HStack {
                                            Button("Implemented") { Task { await viewModel.updateFeedback(recommendation, status: "implemented") } }
                                            Button("Ignore", role: .destructive) { Task { await viewModel.updateFeedback(recommendation, status: "ignored") } }
                                        }
                                        .font(.caption)
                                    } else {
                                        Text(recommendation.status.capitalized).font(.caption).foregroundStyle(.secondary)
                                        if recommendation.status == "implemented" && recommendation.outcome == nil {
                                            Menu {
                                                Button("Useful") { Task { await viewModel.recordOutcome(recommendation, outcome: "useful") } }
                                                Button("Ineffective") { Task { await viewModel.recordOutcome(recommendation, outcome: "ineffective") } }
                                                Button("Harmful", role: .destructive) { Task { await viewModel.recordOutcome(recommendation, outcome: "harmful") } }
                                            } label: {
                                                Label("How did it work?", systemImage: "chart.line.text.clipboard")
                                                    .font(.caption)
                                            }
                                        } else if let outcome = recommendation.outcome {
                                            Text("Outcome: \(outcome.capitalized)")
                                                .font(.caption)
                                                .foregroundStyle(outcome == "harmful" ? .red : .secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
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

    private var advisorSummary: String {
        let fieldName = viewModel.activeField?.name ?? "Selected field"
        let count = viewModel.recommendations.count
        if count == 0 {
            return "\(fieldName) · Preparing recommendations"
        }
        return "\(fieldName) · \(count) recommendation\(count == 1 ? "" : "s")"
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
