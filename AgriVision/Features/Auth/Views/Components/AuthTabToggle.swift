import SwiftUI

struct AuthTabToggle: View {
    @Binding var selectedTab: AuthTab
    
    var body: some View {
        ZStack {
            // Background capsule
            Capsule()
                .fill(Color.authCream)
                .frame(width: UIConstants.Auth.toggleWidth, height: UIConstants.Auth.toggleHeight)
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 0)
                .overlay(
                    Capsule().fill(Color.authCream.opacity(0.5))
                )

            HStack(spacing: 0) {
                // Login Tab
                Button(action: {
                    withAnimation(.spring()) {
                        selectedTab = .login
                    }
                }) {
                    Text("Login")
                        .font(.system(size: 16, weight: selectedTab == .login ? .bold : .medium))
                        .foregroundColor(selectedTab == .login ? .white : .authGreen)
                        .frame(width: UIConstants.Auth.tabWidth, height: UIConstants.Auth.toggleHeight)
                }
                .background(
                    ZStack {
                        if selectedTab == .login {
                            Capsule()
                                .fill(LinearGradient.authTabSelection)
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
                        .font(.system(size: 16, weight: selectedTab == .signup ? .bold : .medium))
                        .foregroundColor(selectedTab == .signup ? .white : .authGreen)
                        .frame(width: UIConstants.Auth.tabWidth, height: UIConstants.Auth.toggleHeight)
                }
                .background(
                    ZStack {
                        if selectedTab == .signup {
                            Capsule()
                                .fill(LinearGradient.authTabSelection)
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
