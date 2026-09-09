import SwiftUI

/**
 `SplashView` is the very first thing the user sees when launching AgriVision.
 It features a cinematic logo animation on a clean background.
 */
struct SplashView: View {
    @State private var isVisible = false
    @State private var scale: CGFloat = 0.8
    
    var body: some View {
        ZStack {
            // Cream background as requested by the user for a clean, premium look.
            Theme.Colors.background
                .ignoresSafeArea()
            
            VStack {
                // The main AgriVision logo asset.
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 180, height: 180)
                    .scaleEffect(scale)
                    .opacity(isVisible ? 1 : 0)
                    .shadow(color: Theme.Colors.primaryMedium.opacity(0.1), radius: 20, x: 0, y: 10)
            }
        }
        .onAppear {
            // A subtle, professional "entrance" animation.
            withAnimation(.easeOut(duration: 1.2)) {
                isVisible = true
                scale = 1.0
            }
        }
    }
}

#Preview {
    SplashView()
}
