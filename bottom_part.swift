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
                    .frame(width: 90, height: 90)
                    .offset(y: 45) // Push the circle down so top half is visible inside bounds
                    
                    Text("\(moisture)%")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundColor(AppColors.charcoalGreen)
                        .offset(y: -4)
                }
                .frame(width: 90, height: 45, alignment: .top) // Clip exactly to the half circle
                .clipped()
                
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

struct PHBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = 4
        let pointerWidth: CGFloat = 8
        let pointerHeight: CGFloat = 6
        
        let roundedRect = CGRect(x: 0, y: 0, width: rect.width, height: rect.height - pointerHeight)
        
        path.addRoundedRect(in: roundedRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        
        // Add downward pointer at bottom center
        path.move(to: CGPoint(x: rect.midX - pointerWidth/2, y: roundedRect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX + pointerWidth/2, y: roundedRect.maxY))
        
        return path
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
