struct MoistureCardView: View {
    var moisture: Int
    var history: [Double] = [30, 45, 60, 50, 40, .nan] // initialized dynamically
    
    init(moisture: Int, history: [Double]? = nil) {
        self.moisture = moisture
        if let history = history, history.count > 1 {
            self.history = history
        } else {
            self.history = [40, 55, 30, 60, 45, Double(moisture)]
        }
    }
    
    var body: some View {
        LiquidGlassCard {
            ZStack(alignment: .top) {
                // Background wave logic
                VStack(spacing: 0) {
                    Spacer()
                    ZStack {
                        FilledSparklineShape(data: history)
                            .fill(AppColors.limeGreen.opacity(0.3))
                        
                        SparklineShape(data: history)
                            .stroke(AppColors.mediumGreen, lineWidth: 1.5)
                    }
                    .frame(height: 38)
                    .padding(.bottom, -5)
                }
                
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.cyan) // water blue
                            .shadow(color: Color.black.opacity(0.2), radius: 2, y: 2)
                        
                        Text("Soil\nMoisture")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.charcoalGreen)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .shadow(color: Color.black.opacity(0.1), radius: 1, y: 1)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppColors.mediumGreen)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    
                    Spacer()
                    
                    // Gauge Area
                    ZStack(alignment: .bottom) {
                        // Empty Bar
                        HalfCircleShape()
                            .stroke(AppColors.limeGreen.opacity(0.5), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        
                        // Filled Bar
                        HalfCircleShape()
                            .trim(from: 0, to: CGFloat(moisture)/100.0)
                            .stroke(AppColors.mediumGreen, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        
                        // Indicator Dot
                        Circle()
                            .fill(AppColors.mediumGreen)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color.white, lineWidth: 3))
                            .shadow(color: .black.opacity(0.15), radius: 3)
                            .offset(x: -50) // radius
                            .rotationEffect(.degrees(180 * (Double(moisture) / 100.0)))
                            .offset(y: 4) // Center onto the border trace visually
                        
                        Text("\(moisture)%")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(AppColors.charcoalGreen)
                            .offset(y: 8) // Push down slightly since it's a half-circle
                    }
                    .frame(width: 100, height: 50)
                    .padding(.top, 4)
                    
                    Spacer()
                    
                    Text("Optimal Value: 30-50")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(AppColors.mediumGreen)
                    
                    Spacer().frame(height: 18) // give graph breathing room
                }
            }
        }
    }
}
