import SwiftUI

// This view draws a single wave that can be shifted horizontally.
struct BackgroundWave: View {
    let horizontalOffset: CGFloat // This is how much the wave has moved based on swiping.
    
    var body: some View {
        // GeometryReader lets us know the size of the screen.
        GeometryReader { proxy in
            // These numbers are based on the original design dimensions.
            // Increased to 2100 to ensure the extended path isn't clipped.
            let baseWidth: CGFloat = 2100
            let screenWidth = proxy.size.width
            let scale = screenWidth / 900 // Scales the wave to fit different screen sizes.
            
            // A gradient color from light green to medium green.
            let gradient = LinearGradient(
                colors: [Theme.Colors.primaryLight, Theme.Colors.primaryMedium],
                startPoint: .leading,
                endPoint: .trailing
            )
            
            // Draws the custom wave shape.
            BackgroundWaveShape()
                .stroke(
                    gradient,
                    style: StrokeStyle(
                        lineWidth: 300 * scale, // Makes the wave look thick and "premium".
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .drawingGroup() // Flattens the view into a single GPU-rendered layer for performance.
                // Moves the wave based on the current page and vertical position.
                .offset(x: horizontalOffset, y: 420 * scale)
                .frame(width: baseWidth * scale)
        }
    }
}

// A custom shape that defines the "curvy" path of the wave.
private struct BackgroundWaveShape: Shape {
    /// Builds the four-segment bezier wave path used for the onboarding background.
    /// Extracted as a named helper so `path(in:)` does not duplicate the same curves.
    private func makeCurvyPath() -> Path {
        var path = Path()
        
        // We move the "pen" to a starting point and then draw curves.
        // Curves use "control points" to create the smooth, organic look.
        path.move(to: CGPoint(x: -50, y: 150))
        
        // First curve
        path.addCurve(to: CGPoint(x: 450, y: 100),
                      control1: CGPoint(x: 150, y: 220),
                      control2: CGPoint(x: 250, y: 20))
        
        // Second curve
        path.addCurve(to: CGPoint(x: 950, y: 160),
                      control1: CGPoint(x: 650, y: 180),
                      control2: CGPoint(x: 750, y: 280))
        
        // Third curve
        path.addCurve(to: CGPoint(x: 1450, y: 120),
                      control1: CGPoint(x: 1150, y: 40),
                      control2: CGPoint(x: 1250, y: 200))
        
        // Fourth curve (Added to extend length for the 3rd page parallax shift)
        path.addCurve(to: CGPoint(x: 1950, y: 150),
                      control1: CGPoint(x: 1650, y: 60),
                      control2: CGPoint(x: 1750, y: 240))
        
        return path
    }

    func path(in _: CGRect) -> Path {
        // Delegate to the shared helper to avoid duplicating the bezier-curve path.
        return makeCurvyPath()
    }
}

// This is the background for the entire onboarding view.
// It includes the cream color and the animated wave on top.
struct WaveBackground: View {
    // The continuous horizontal position of the pages during a swipe.
    let scrollOffset: CGFloat
    
    var body: some View {
        GeometryReader { proxy in
            let screenWidth = proxy.size.width
            
            // We calculate how much the wave should shift based on the scroll position.
            // Using a multiplier (like 0.45) creates a parallax-like effect where 
            // the background moves slower than the foreground content.
            // The scrollOffset is usually negative (moving left), so we use it directly.
            let animationOffset = scrollOffset * UIConstants.Onboarding.pageTransitionOffsetMultiplier
            
            ZStack {
                // The base cream color that covers the whole screen.
                Theme.Colors.background
                    .ignoresSafeArea()
                
                // The actual thick wave moving behind our content.
                BackgroundWave(horizontalOffset: animationOffset)
                // .blur removed for "crystal clear" look requested by user.
            }
        }
    }
}


// Preview allows us to see the background without running the whole app.
#Preview {
     WaveBackground(scrollOffset: 0)
}


