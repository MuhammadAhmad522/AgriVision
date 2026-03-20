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
                        .font(.system(size: 16, weight: selectedTab == .login ? .bold : .medium))
                        .foregroundColor(selectedTab == .login ? AppColors.cream : AppColors.charcoalGreen)
                        .frame(width: UIConstants.Auth.tabWidth, height: UIConstants.Auth.toggleHeight)
                }
                .background(
                    ZStack {
                        if selectedTab == .login {
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [AppColors.limeGreen, AppColors.mediumGreen],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .padding(4)
                                .shadow(color: AppColors.mediumGreen.opacity(0.3), radius: 4, x: 0, y: 2)
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
                        .foregroundColor(selectedTab == .signup ? AppColors.cream : AppColors.charcoalGreen)
                        .frame(width: UIConstants.Auth.tabWidth, height: UIConstants.Auth.toggleHeight)
                }
                .background(
                    ZStack {
                        if selectedTab == .signup {
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [AppColors.limeGreen, AppColors.mediumGreen],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .padding(4)
                                .shadow(color: AppColors.mediumGreen.opacity(0.3), radius: 4, x: 0, y: 2)
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
