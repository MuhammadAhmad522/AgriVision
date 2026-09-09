import SwiftUI

/// Semantic text styles for the AgriVision application.
public enum TextStyle {
    /// Large, prominent headers (e.g., Dashboard greetings)
    case display
    /// Screen titles
    case title1
    case title2
    case title3
    /// Standard body text
    case body
    case bodyStrong
    /// Smaller supporting text
    case caption
    case captionStrong
}

public struct TypographyModifier: ViewModifier {
    let style: TextStyle
    
    public func body(content: Content) -> some View {
        content
            .font(fontForStyle(style))
            .foregroundColor(colorForStyle(style))
            .lineSpacing(lineSpacingForStyle(style))
            .tracking(trackingForStyle(style))
    }
    
    private func fontForStyle(_ style: TextStyle) -> Font {
        // Using standard system fonts with adjusted weights for a modern feel.
        switch style {
        case .display:
            return .system(size: 34, weight: .bold, design: .rounded)
        case .title1:
            return .system(size: 28, weight: .bold, design: .rounded)
        case .title2:
            return .system(size: 22, weight: .semibold, design: .rounded)
        case .title3:
            return .system(size: 20, weight: .semibold, design: .default)
        case .body:
            return .system(size: 16, weight: .regular, design: .default)
        case .bodyStrong:
            return .system(size: 16, weight: .semibold, design: .default)
        case .caption:
            return .system(size: 13, weight: .regular, design: .default)
        case .captionStrong:
            return .system(size: 13, weight: .semibold, design: .default)
        }
    }
    
    private func colorForStyle(_ style: TextStyle) -> Color {
        switch style {
        case .display, .title1, .title2, .title3, .bodyStrong, .captionStrong:
            return Theme.Colors.textPrimary
        case .body, .caption:
            return Theme.Colors.textSecondary
        }
    }
    
    private func lineSpacingForStyle(_ style: TextStyle) -> CGFloat {
        switch style {
        case .display, .title1: return 8
        case .title2, .title3: return 6
        case .body, .bodyStrong: return 4
        case .caption, .captionStrong: return 2
        }
    }
    
    private func trackingForStyle(_ style: TextStyle) -> CGFloat {
        switch style {
        case .display: return 0.5
        case .title1, .title2: return 0.3
        case .title3: return 0.2
        case .body, .bodyStrong: return 0.0
        case .caption, .captionStrong: return 0.2
        }
    }
}

public extension View {
    /// Applies the global AgriVision typography styles to the view.
    func textStyle(_ style: TextStyle) -> some View {
        self.modifier(TypographyModifier(style: style))
    }
}
