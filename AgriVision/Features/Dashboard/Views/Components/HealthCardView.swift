import SwiftUI

struct HealthCardView: View {
    var healthScore: Double?
    var cropType: String
    
    @State private var animatedProgress: Double = 0.0
    
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
                Image(systemName: "leaf.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 110, height: 110)
                    .foregroundColor(Theme.Colors.primaryMedium)
            }
            
            Text("\(cropType.capitalized) Field")
                .textStyle(.title2)
                .foregroundColor(Theme.Colors.primary)
                .padding(.top, 4)
            
            ZStack {
                // Background Track Ring
                Circle()
                    .stroke(Theme.Colors.primaryLight.opacity(0.25), lineWidth: 9)
                
                // Animated Progress Ring
                Circle()
                    .trim(from: 0, to: CGFloat(animatedProgress))
                    .stroke(
                        LinearGradient(
                            colors: [Theme.Colors.primaryLight, Theme.Colors.primaryMedium],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                // Animating Percentage Text Counter
                AnimatedPercentageText(
                    progress: animatedProgress,
                    hasValue: healthScore != nil
                )
            }
            .frame(width: 80, height: 80)
            .padding(.top, 8)
            
            Text("Health")
                .textStyle(.bodyStrong)
                .foregroundColor(Theme.Colors.primary)
                .padding(.top, 4)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 1.25, dampingFraction: 0.76, blendDuration: 0.25)) {
                    animatedProgress = healthScore ?? 0.0
                }
            }
        }
        .onChange(of: healthScore) { newScore in
            withAnimation(.spring(response: 1.25, dampingFraction: 0.76, blendDuration: 0.25)) {
                animatedProgress = newScore ?? 0.0
            }
        }
    }
}

// MARK: - Animatable Percentage Text
private struct AnimatedPercentageText: View, Animatable {
    var progress: Double
    var hasValue: Bool
    
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    
    var body: some View {
        if hasValue {
            Text("\(Int(progress * 100))%")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.primary)
        } else {
            Text("--")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.primary)
        }
    }
}
