import SwiftUI

struct AuthContainerView: View {
    @StateObject private var viewModel: AuthViewModel
    @StateObject private var loginViewModel: LoginViewModel
    @StateObject private var signupViewModel: SignupViewModel
    
    @State private var containerHeight: CGFloat = 0

    // The Coordinator creates these ViewModels and passes them in.
    // Using @StateObject here ensures this View keeps them alive in memory
    // rather than accidentally destroying them during UI redraws.
    init(viewModel: AuthViewModel, loginViewModel: LoginViewModel, signupViewModel: SignupViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self._loginViewModel = StateObject(wrappedValue: loginViewModel)
        self._signupViewModel = StateObject(wrappedValue: signupViewModel)
    }

    var body: some View {
        ZStack {
            // Background Image
            Image("bg-image")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            // We use GeometryReader to get the dynamic screen size instead of
            // UIScreen.main.bounds, making this view more adaptable to different devices.
            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack {
                        Spacer(minLength: UIConstants.Auth.scrollSpacerMinLength)

                        VStack(spacing: 20) {
                            // Tab Toggle — bound to the ViewModel's published state.
                            AuthTabToggle(selectedTab: $viewModel.selectedTab)
                                .padding(.top, UIConstants.Auth.cardTopPadding)

                            // Forms — animation lives in the View; state lives in the ViewModel.
                            ZStack {
                                if viewModel.selectedTab == .login {
                                    LoginView(viewModel: loginViewModel, onSignupTap: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            viewModel.switchToSignup()
                                        }
                                    })
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                                } else {
                                    SignupView(viewModel: signupViewModel, onLoginTap: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            viewModel.switchToLogin()
                                        }
                                    })
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .leading).combined(with: .opacity),
                                        removal: .move(edge: .trailing).combined(with: .opacity)
                                    ))
                                }
                            }
                        }
                        .padding(.horizontal, UIConstants.Auth.cardHorizontalPadding)
                        .frame(width: UIConstants.Auth.cardWidth)
                        .glassmorphism(cornerRadius: UIConstants.Auth.cardCornerRadius)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.selectedTab)

                        Spacer(minLength: UIConstants.Auth.scrollSpacerMinLength)
                    }
                    .frame(maxWidth: .infinity, minHeight: containerHeight > 0 ? containerHeight : proxy.size.height)
                }
                .onAppear {
                    // Capture initial height so layout doesn't jump and conflict with keyboard avoidance
                    if containerHeight == 0 {
                        containerHeight = proxy.size.height
                    }
                }
            }
        }
        .onTapGesture {
            // Dismiss keyboard when tapping away from input fields.
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

#Preview {
    AuthContainerView(
        viewModel: AuthViewModel(),
        loginViewModel: LoginViewModel(authService: MockAuthService(), preferencesService: MockPreferencesService()),
        signupViewModel: SignupViewModel(authService: MockAuthService(), userProfileService: MockUserProfileService())
    )
}

/// A custom, reusable modifier that applies a frosted-glass, multi-layered background effect.
/// Use `.glassmorphism(cornerRadius:)` on any SwiftUI View to achieve the premium aesthetic.
struct GlassmorphismModifier: ViewModifier {
    var cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(0.1))
                    .background(
                        Color.white.opacity(0.1)
                            .blur(radius: 20)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
    }
}

extension View {
    func glassmorphism(cornerRadius: CGFloat) -> some View {
        self.modifier(GlassmorphismModifier(cornerRadius: cornerRadius))
    }
}
