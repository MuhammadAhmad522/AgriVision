import SwiftUI

public enum AgriButtonStyle {
    case primary
    case secondary
    case ghost
}

public struct AgriButton: View {
    let title: String
    let style: AgriButtonStyle
    let isLoading: Bool
    let action: () -> Void
    
    public init(
        title: String,
        style: AgriButtonStyle = .primary,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isLoading = isLoading
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            if !isLoading {
                #if os(iOS)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                #endif
                action()
            }
        }) {
            ZStack {
                // Background
                switch style {
                case .primary:
                    Theme.Gradients.brandGradient
                case .secondary:
                    Theme.Colors.surfaceHighlight
                case .ghost:
                    Color.clear
                }
                
                // Content
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                } else {
                    Text(title)
                        .textStyle(.bodyStrong)
                        .foregroundColor(textColor)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .stroke(
                        style == .ghost ? Theme.Colors.surfaceHighlight : Color.clear,
                        lineWidth: 2
                    )
            )
            .shadow(
                color: style == .primary ? Theme.Shadows.primaryGlow : Color.clear,
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .disabled(isLoading)
        .pressScale() // Requires Animations.swift modifier
    }
    
    private var textColor: Color {
        switch style {
        case .primary, .ghost:
            return Theme.Colors.textPrimary
        case .secondary:
            return Theme.Colors.textPrimary
        }
    }
}
