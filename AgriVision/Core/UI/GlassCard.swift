import SwiftUI

/// A reusable container that applies the app's signature "Liquid Glass" styling.
/// Used for grouping content in Dashboard, Settings, and other list-like views.
struct GlassCard<Content: View>: View {
    var title: String?
    let content: Content
    
    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppColors.charcoalGreen.opacity(0.8))
                    .padding(.leading, 4)
            }
            
            VStack {
                content
            }
            .padding()
            .background(
                ZStack {
                    VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                    Color.white.opacity(0.6)
                }
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: AppColors.mediumGreen.opacity(0.1), radius: 10, x: 0, y: 5)
        }
    }
}

#Preview {
    ZStack {
        Color(AppColors.cream).ignoresSafeArea()
        GlassCard(title: "Preview Card") {
            Text("This is content inside a glass card.")
                .foregroundColor(AppColors.charcoalGreen)
        }
        .padding()
    }
}
