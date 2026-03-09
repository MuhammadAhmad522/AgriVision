import SwiftUI

struct SocialAuthButton: View {
    let title: String
    /// Optional override for the system icon. Defaults to `"g.circle.fill"` so that existing
    /// call sites (Google login) require no change, while future providers can pass their own icon.
    let systemImage: String?
    let action: () -> Void

    init(title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage ?? "g.circle.fill")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.authGreen)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.authGreen)
            }
            .frame(width: UIConstants.Auth.formWidth, height: UIConstants.Auth.socialButtonHeight)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.authBorder, lineWidth: 1)
            )
        }
    }
}

#Preview {
    SocialAuthButton(title: "Continue with Google") {
        print("Google login tapped")
    }
    .padding()
    .background(Color.authCream)
}
