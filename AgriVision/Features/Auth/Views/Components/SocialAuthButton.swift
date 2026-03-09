import SwiftUI

struct SocialAuthButton: View {
    let title: String
    let systemImage: String? = nil // Could use for other social logins
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Using a system icon as a placeholder for Google if no asset is provided
                // In a real app, this would be the Google G logo asset
                Image(systemName: "g.circle.fill")
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
