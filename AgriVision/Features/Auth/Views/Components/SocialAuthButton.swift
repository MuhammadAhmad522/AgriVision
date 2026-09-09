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
                    .frame(width: 24, height: 24)
                    .foregroundColor(Theme.Colors.primary) // Use theme color

                Text(title)
                    .textStyle(.bodyStrong)
                    .foregroundColor(Theme.Colors.primary)
            }
            .frame(width: UIConstants.Auth.formWidth, height: 50)
            .background(
                ZStack {
                    VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                    Color.white.opacity(0.6)
                }
            )
            .cornerRadius(25) // Match Primary Button
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
}

#Preview {
    SocialAuthButton(title: "Continue with Google") {
        print("Google login tapped")
    }
    .padding()
    .background(Theme.Colors.background)
}
