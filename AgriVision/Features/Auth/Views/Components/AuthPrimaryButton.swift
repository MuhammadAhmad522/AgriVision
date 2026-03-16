import SwiftUI

struct AuthPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(isLoading ? 0 : 1)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
            .frame(width: UIConstants.Auth.formWidth, height: UIConstants.Auth.primaryButtonHeight)
            .background(LinearGradient.authPrimaryGradient)
            .cornerRadius(8)
            .shadow(color: AppColors.authDarkGreen.opacity(0.3), radius: 8, x: 0, y: 4)
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
