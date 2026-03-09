import SwiftUI

struct AuthPrimaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: UIConstants.Auth.formWidth, height: UIConstants.Auth.primaryButtonHeight)
                .background(LinearGradient.authPrimaryGradient)
                .cornerRadius(8)
                .shadow(color: AppColors.authDarkGreen.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

#Preview {
    AuthPrimaryButton(title: "Login") {
        print("Button tapped")
    }
    .padding()
}
