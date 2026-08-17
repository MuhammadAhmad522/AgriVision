import SwiftUI

struct AuthTabToggle: View {
    @Binding var selectedTab: AuthTab
    
    var body: some View {
        ZStack {
            // Background capsule
            Capsule()
                .fill(Color.clear)
                .frame(width: UIConstants.Auth.toggleWidth, height: UIConstants.Auth.toggleHeight)
                .background(
                    ZStack {
                        VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                        Color.white.opacity(0.4)
                    }
                    .clipShape(Capsule())
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)

            HStack(spacing: 0) {
                // Login Tab
                Button(action: {
                    withAnimation(.spring()) {
                        selectedTab = .login
                    }
                }) {
                    Text("Login")
                        .textStyle(selectedTab == .login ? .bodyStrong : .body)
                        .foregroundColor(selectedTab == .login ? Theme.Colors.background : Theme.Colors.primary)
                        .frame(width: UIConstants.Auth.tabWidth, height: UIConstants.Auth.toggleHeight)
                }
                .background(
                    ZStack {
                        if selectedTab == .login {
                            Capsule()
                                .fill(Theme.Gradients.brandGradient)
                                .padding(4)
                                .shadow(color: Theme.Colors.primary.opacity(0.3), radius: 4, x: 0, y: 2)
                                .matchedGeometryEffect(id: "tab", in: animation)
                        }
                    }
                )

                // Signup Tab
                Button(action: {
                    withAnimation(.spring()) {
                        selectedTab = .signup
                    }
                }) {
                    Text("Signup")
                        .textStyle(selectedTab == .signup ? .bodyStrong : .body)
                        .foregroundColor(selectedTab == .signup ? Theme.Colors.background : Theme.Colors.primary)
                        .frame(width: UIConstants.Auth.tabWidth, height: UIConstants.Auth.toggleHeight)
                }
                .background(
                    ZStack {
                        if selectedTab == .signup {
                            Capsule()
                                .fill(Theme.Gradients.brandGradient)
                                .padding(4)
                                .shadow(color: Theme.Colors.primary.opacity(0.3), radius: 4, x: 0, y: 2)
                                .matchedGeometryEffect(id: "tab", in: animation)
                        }
                    }
                )
            }
            .frame(width: UIConstants.Auth.toggleWidth, height: UIConstants.Auth.toggleHeight)
            .clipShape(Capsule())
        }
    }
    
    @Namespace private var animation
}

#Preview {
    @Previewable @State var selectedTab: AuthTab = .login
    AuthTabToggle(selectedTab: $selectedTab)
}
