import SwiftUI

public struct PressScaleModifier: ViewModifier {
    @State private var isPressed = false
    
    public func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

public extension View {
    /// Applies a gentle scaling animation when the view is pressed.
    func pressScale() -> some View {
        self.modifier(PressScaleModifier())
    }
}
