import SwiftUI

enum CardEntranceEdge {
    case leading   // Slides in from left
    case trailing  // Slides in from right
}

struct LiquidGlassCard<Content: View>: View {
    let content: Content
    var edge: CardEntranceEdge
    var delay: Double
    
    @State private var isVisible: Bool = false
    
    init(edge: CardEntranceEdge = .leading, delay: Double = 0.18, @ViewBuilder content: () -> Content) {
        self.edge = edge
        self.delay = delay
        self.content = content()
    }
    
    private var initialXOffset: CGFloat {
        edge == .leading ? -45 : 45
    }
    
    private var initialYRotation: Double {
        edge == .leading ? 22 : -22
    }
    
    private var rotationAnchor: UnitPoint {
        edge == .leading ? .leading : .trailing
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.85))
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
            
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .frame(minHeight: 164)
        .opacity(isVisible ? 1.0 : 0.0)
        .offset(x: isVisible ? 0 : initialXOffset)
        .scaleEffect(isVisible ? 1.0 : 0.90)
        .rotation3DEffect(
            .degrees(isVisible ? 0 : initialYRotation),
            axis: (x: 0, y: 1, z: 0),
            anchor: rotationAnchor,
            perspective: 0.5
        )
        .animation(.spring(response: 1.15, dampingFraction: 0.82, blendDuration: 0.35), value: isVisible)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 1.15, dampingFraction: 0.82, blendDuration: 0.35)) {
                    isVisible = true
                }
            }
        }
    }
}
