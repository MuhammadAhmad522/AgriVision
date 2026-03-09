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
        }
    }
}

#Preview {
    AuthPrimaryButton(title: "Login") {
        print("Button tapped")
    }
    .padding()
}
