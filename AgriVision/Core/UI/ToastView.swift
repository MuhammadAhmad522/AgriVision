import SwiftUI

enum ToastType {
    case success
    case error
    
    var color: Color {
        switch self {
        case .success: return AppColors.limeGreen
        case .error: return .red
        }
    }
    
    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

struct ToastView: View {
    let message: String
    let type: ToastType
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.iconName)
                .font(.title3)
                .foregroundColor(type.color) // Icon takes the color
            
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.leading)
                .foregroundColor(AppColors.charcoalGreen) // Text dark for readability on glass
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            ZStack {
                VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                type.color.opacity(0.2) // Subtle tint
            }
            .clipShape(Capsule())
        )
        .overlay(
            Capsule()
                .stroke(type.color.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: type.color.opacity(0.3), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 16)
    }
}

#Preview {
    VStack(spacing: 20) {
        ToastView(message: "Success! Action completed.", type: .success)
        ToastView(message: "Error! Something went wrong.", type: .error)
    }
}
