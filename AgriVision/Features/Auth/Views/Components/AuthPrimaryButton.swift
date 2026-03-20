import SwiftUI

struct AuthPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background Gradient
                LinearGradient(
                    colors: [AppColors.limeGreen, AppColors.mediumGreen],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Glassy Sheen Overlay
                LinearGradient(
                    colors: [Color.white.opacity(0.3), Color.white.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .center
                )
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .padding(1) // Inset slightly
                
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.cream)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .opacity(isLoading ? 0 : 1)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
            .frame(width: UIConstants.Auth.formWidth, height: 50)
            .cornerRadius(25)
            .shadow(color: AppColors.mediumGreen.opacity(0.4), radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isLoading)
    }
}

#Preview {
    VStack {
        AuthPrimaryButton(title: "Login") {
            print("Button tapped")
        }
        AuthPrimaryButton(title: "Loading...", isLoading: true) {
            print("Button tapped")
        }
    }
    .padding()
}
