import SwiftUI

enum ToastType {
    case success
    case error
    
    var color: Color {
        switch self {
        case .success: return AppColors.mediumGreen
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
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.leading)
        }
        .foregroundColor(.white)
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(type.color.opacity(0.95))
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }
}

#Preview {
    VStack(spacing: 20) {
        ToastView(message: "Success! Action completed.", type: .success)
        ToastView(message: "Error! Something went wrong.", type: .error)
    }
}
