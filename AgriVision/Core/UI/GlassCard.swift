import SwiftUI

/// A reusable container that applies the app's signature "Liquid Glass" styling.
/// Used for grouping content in Dashboard, Settings, and other list-like views.
public struct GlassCard<Content: View>: View {
    var title: String?
    let content: Content
    
    public init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            if let title = title {
                Text(title)
                    .textStyle(.title3)
                    .padding(.leading, 4)
            }
            
            VStack {
                content
            }
            .padding()
            .background(
                ZStack {
                    VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                    Theme.Gradients.glassOverlay
                }
            )
            .cornerRadius(Theme.Radius.large)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.large)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Theme.Shadows.soft, radius: 10, x: 0, y: 5)
        }
    }
}

#Preview {
    ZStack {
        Theme.Colors.background.ignoresSafeArea()
        GlassCard(title: "Preview Card") {
            Text("This is content inside a glass card.")
                .textStyle(.body)
        }
        .padding()
    }
}
