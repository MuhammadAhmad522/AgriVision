import SwiftUI

struct BackgroundWave: View {
    let horizontalOffset: CGFloat // Synchronized with page transitions
    
    var body: some View {
        GeometryReader { proxy in
            // baseWidth from Figma CSS: 1322px
            let baseWidth: CGFloat = 1322
            let screenWidth = proxy.size.width
            let scale = screenWidth / 900 // Scale relative to Figma screen width
            
            let gradient = LinearGradient(
                colors: [AppColors.limeGreen, AppColors.mediumGreen],
                startPoint: .leading,
                endPoint: .trailing
            )
            
            BackgroundWaveShape()
                .stroke(
                    gradient,
                    style: StrokeStyle(
                        lineWidth: 300 * scale, // Thicker for the "zoomed-in" look
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .offset(x: horizontalOffset, y: 420 * scale)
                .frame(width: baseWidth * scale)
        }
    }
}

private struct BackgroundWaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // coordinates spanning across 3 screens (approx 1322 Figma px)
        // Path adjusted to match the organic flow of the provided user image
        path.move(to: CGPoint(x: -50, y: 150))
        path.addCurve(to: CGPoint(x: 450, y: 100),
                      control1: CGPoint(x: 150, y: 220),
                      control2: CGPoint(x: 250, y: 20))
        path.addCurve(to: CGPoint(x: 950, y: 160),
                      control1: CGPoint(x: 650, y: 180),
                      control2: CGPoint(x: 750, y: 280))
        path.addCurve(to: CGPoint(x: 1450, y: 120),
                      control1: CGPoint(x: 1150, y: 40),
                      control2: CGPoint(x: 1250, y: 200))
        
        return path
    }
}

struct WaveBackground: View {
    let currentPage: Int
    
    var body: some View {
        GeometryReader { proxy in
            let screenWidth = proxy.size.width
            // Calculate offset based on current page
            let animationOffset = -CGFloat(currentPage) * (screenWidth * 0.45)
            
            ZStack {
                AppColors.cream
                    .ignoresSafeArea()
                
                // Single, premium thick wave as requested
                BackgroundWave(horizontalOffset: animationOffset)
                    .blur(radius: 2) // Subtle softening for a premium feel
            }
        }
    }
}

#Preview {
     WaveBackground(currentPage: 0)
}
