import SwiftUI

struct DashboardView: View {
    @StateObject var viewModel: DashboardViewModel
    
    // State for the draggable bottom sheet
    @State private var sheetHeight: CGFloat = 260
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            Image("bg-image")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            // Fixed Background Elements
            VStack(alignment: .leading, spacing: 12) {
                // Top Custom Navigation Bar
                DashboardHeaderView(userName: viewModel.userName ?? "Ahmad")
                    .padding(.top, 10) // Reduced to tuck it further upwards
                
                // Weather & Field Health Section
                HStack(alignment: .center, spacing: 0) {
                    WeatherCardView()
                        .frame(width: UIScreen.main.bounds.width * 0.55)
                    
                    Spacer()
                    
                    HealthCardView(healthScore: viewModel.healthSummary?.score ?? 0.75, cropType: viewModel.currentCropType)
                        .padding(.trailing, 20)
                }
                
                // Three Metrics Cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        MoistureCardView(moisture: 69)
                        PHLevelCardView(phLevel: 6.5)
                        NDVICardView(ndvi: viewModel.healthSummary?.score ?? 0.86)
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            
            // Bottom Alerts Sheet (Draggable)
            AlertsBottomSheet(viewModel: viewModel)
                .frame(height: sheetHeight)
                .offset(y: 20) // Push a bit down to allow tab bar space
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newHeight = sheetHeight - value.translation.height
                            // Keep height within bounds
                            if newHeight > 200 && newHeight < UIScreen.main.bounds.height * 0.75 {
                                sheetHeight = newHeight
                            }
                        }
                )
            
            // Custom Floating Tab Bar (At the very top of the ZStack)
            CustomTabBar()
                .padding(.bottom, 20)
        }
        .navigationBarHidden(true)
        .onAppear {
            Task {
                await viewModel.refreshData()
            }
        }
    }
}

// MARK: - Components

struct DashboardHeaderView: View {
    var userName: String
    
    var body: some View {
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
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(AppColors.charcoalGreen)
        }
        .padding(.horizontal, 18)
        
        HStack {
            Text("Hi, \(userName)")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppColors.charcoalGreen)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8) // Reduced from 16
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
                Text("24°C")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white)
                Text("H:16° L:8°")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
                
                HStack {
                    Text("Lahore, Pakistan")
                        .font(.system(size: 14))
                    Spacer()
                    Text("Showers")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.top, 12)
            }
            .padding(.leading, 20)
            .padding(.trailing, 20)
            .padding(.bottom, 20)
            
            // 3D Weather Icons Layout mapping
            GeometryReader { geo in
                Image(systemName: "cloud.sun.rain.fill") // Placeholder for 3D Icon
                    .renderingMode(.original)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 5, y: 10)
                    .position(x: geo.size.width - 10, y: 40)
            }
        }
        .frame(height: 180)
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
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        }
        .frame(width: 140, height: 164)
    }
}

struct WaveLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Closer match to Figma's specific wave outline
        path.move(to: CGPoint(x: 0, y: rect.height * 0.4))
        
        // first dip
        path.addCurve(
            to: CGPoint(x: rect.width * 0.25, y: rect.height * 0.7),
            control1: CGPoint(x: rect.width * 0.05, y: rect.height * 0.4),
            control2: CGPoint(x: rect.width * 0.1, y: rect.height * 0.7)
        )
        
        // big peak
        path.addCurve(
            to: CGPoint(x: rect.width * 0.55, y: rect.height * 0.1),
            control1: CGPoint(x: rect.width * 0.4, y: rect.height * 0.7),
            control2: CGPoint(x: rect.width * 0.45, y: rect.height * 0.1)
        )
        
        // second dip
        path.addCurve(
            to: CGPoint(x: rect.width * 0.8, y: rect.height * 0.8),
            control1: CGPoint(x: rect.width * 0.65, y: rect.height * 0.1),
            control2: CGPoint(x: rect.width * 0.7, y: rect.height * 0.8)
        )
        
        // small final peak
        path.addCurve(
            to: CGPoint(x: rect.width, y: rect.height * 0.5),
            control1: CGPoint(x: rect.width * 0.9, y: rect.height * 0.8),
            control2: CGPoint(x: rect.width * 0.95, y: rect.height * 0.5)
        )
        
        return path
    }
}

struct WaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = WaveLine().path(in: rect)
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
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
                        
                        Circle()
                            .trim(from: 0.5, to: 0.5 + (0.5 * CGFloat(moisture)/100))
                            .stroke(AppColors.mediumGreen, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    }
                    .frame(width: 90, height: 60)
                    .offset(y: 10) // Push the circle down so top half is visible inside bounds
                    
                    Text("\(moisture)%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.charcoalGreen)
                        .offset(y: -20)
                }
                .frame(width: 90, height: 60, alignment: .top) // Clip exactly to the half circle
                .clipped()
                .offset(y: 0)
                
                Spacer(minLength: 0)
                
                Text("Optimal Value: 30-50")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppColors.mediumGreen)
                
                Spacer(minLength: 0)
                
                // Wavy chart background mapping to bottom of card
                ZStack {
                    WaveShape()
                        .fill(AppColors.limeGreen.opacity(0.3))
                    
                    WaveLine()
                        .stroke(AppColors.mediumGreen, lineWidth: 1.5)
                }
                .frame(height: 38)
            }
        }
    }
}

struct PHLevelCardView: View {
    var phLevel: Double
    var body: some View {
        LiquidGlassCard {
            VStack {
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
                
                VStack(spacing: 0) {
                    // Bubble Label
                    Text(String(format: "%.1f", phLevel))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.charcoalGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            PHBubbleShape()
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.1), radius: 2)
                        )
                        .padding(.bottom, 2)
                        .offset(x: -15) // Offset to roughly position over '6.5' mark
                    
                    // Gradient Bar for PH
                    LinearGradient(
                        colors: [.red, .orange, .yellow, .green, .blue, .indigo, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 8)
                    .cornerRadius(4)
                    
                    HStack {
                        Text("4").font(.system(size:9))
                        Spacer()
                        Text("5").font(.system(size:9))
                        Spacer()
                        Text("6").font(.system(size:9))
                        Spacer()
                        Text("7").font(.system(size:9))
                        Spacer()
                        Text("8").font(.system(size:9))
                        Spacer()
                        Text("9").font(.system(size:9))
                    }
                    .foregroundColor(AppColors.charcoalGreen)
                    .padding(.top, 4)
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
            VStack(alignment: .center, spacing: 8) {
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
                
                Text("Vegetation Index")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.mediumGreen)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, -6)
                
                Spacer()
                
                Text(String(format: "%.2f", ndvi))
                    .font(.system(size: 26, weight: .regular))
                    .foregroundColor(AppColors.charcoalGreen)
                
                LinearGradient(
                    colors: [.orange, .yellow, .green],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 12)
                .cornerRadius(6)
                .padding(.horizontal, 24)
                .padding(.top, 4)
                
                Spacer()
                
                Text("Healthy")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.mediumGreen)
                    .padding(.bottom, 22)
            }
        }
    }
}

// MARK: - Shapes
struct SparklineShape: Shape {
    var data: [Double]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let nonNanData = data.filter { !$0.isNaN }
        guard nonNanData.count > 1 else { return path }
        
        let maxValue = nonNanData.max() ?? 1
        let minValue = nonNanData.min() ?? 0
        let range = maxValue - minValue
        
        let stepX = rect.width / CGFloat(data.count - 1)
        
        var points = [CGPoint]()
        for (index, value) in data.enumerated() {
            let x = CGFloat(index) * stepX
            let y = value.isNaN ? rect.height : rect.height - ((CGFloat(value - minValue) / CGFloat(range == 0 ? 1 : range)) * rect.height)
            points.append(CGPoint(x: x, y: y))
        }
        
        if let first = points.first {
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
        return path
    }
}

struct FilledSparklineShape: Shape {
    var data: [Double]
    
    func path(in rect: CGRect) -> Path {
        var path = SparklineShape(data: data).path(in: rect)
        guard !data.isEmpty else { return path }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct HalfCircleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.maxY),
                    radius: rect.width / 2,
                    startAngle: .degrees(180),
                    endAngle: .degrees(0),
                    clockwise: false)
        return path
    }
}

struct PHBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = 4
        let pointerWidth: CGFloat = 8
        let pointerHeight: CGFloat = 6
        
        let roundedRect = CGRect(x: 0, y: 0, width: rect.width, height: rect.height - pointerHeight)
        
        path.addRoundedRect(in: roundedRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        
        path.move(to: CGPoint(x: rect.midX - pointerWidth/2, y: roundedRect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX + pointerWidth/2, y: roundedRect.maxY))
        
        return path
    }
}

// MARK: - Bottom Alerts Card

struct AlertsBottomSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .light)
                .background(Color(AppColors.cream).opacity(0.8).clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous)))
                .shadow(color: .black.opacity(0.1), radius: 20, y: -5)
            
            VStack(spacing: 0) {
                // Grabber
                Capsule()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 50, height: 5)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        AlertRow(iconName: "exclamationmark.circle.fill", iconColor: .orange, text: "Water level is low in mango farm")
                        Divider().padding(.horizontal, 20)
                        AlertRow(iconName: "checkmark.circle.fill", iconColor: .green, text: "Strawberries are ready to harvest")
                        Divider().padding(.horizontal, 20)
                        AlertRow(iconName: "light.beacon.max.fill", iconColor: .red, text: "Locusts are expected to pay a visit tomorrow")
                        Divider().padding(.horizontal, 20)
                        AlertRow(iconName: "checkmark.circle.fill", iconColor: .green, text: "Strawberries are ready to harvest")
                        
                        // Extra space at bottom to scroll past the floating tab bar
                        Spacer().frame(height: 120)
                    }
                    .padding(.horizontal, 24)
                }
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

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    var body: some View {
        HStack {
            TabBarButton(icon: "house.fill", title: "Home", isSelected: true, color: AppColors.mediumGreen)
            Spacer()
            TabBarButton(icon: "leaf.fill", title: "Fields", isSelected: false, color: AppColors.limeGreen)
            Spacer()
            TabBarButton(icon: "gearshape.fill", title: "Settings", isSelected: false, color: AppColors.limeGreen)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.9))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 15, y: 5)
        .padding(.horizontal, 40)
    }
}

struct TabBarButton: View {
    var icon: String
    var title: String
    var isSelected: Bool
    var color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                .foregroundColor(color)
        }
        .frame(width: 60)
        .padding(.vertical, 6)
        .background(isSelected ? Color.gray.opacity(0.1) : Color.clear)
        .clipShape(Capsule())
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
