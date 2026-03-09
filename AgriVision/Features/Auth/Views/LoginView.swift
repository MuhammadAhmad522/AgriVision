import SwiftUI

struct LoginView: View {
    /// `@ObservedObject` — the View observes but does not own the ViewModel;
    /// ownership lives in `AuthContainerView` which was given it by the Coordinator.
    @ObservedObject var viewModel: LoginViewModel
    var onSignupTap: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            AuthTextField(label: "Email", placeholder: "ahmad@mail.com", text: $viewModel.email, keyboardType: .emailAddress, autoCapitalization: .never)

            AuthTextField(label: "Password", placeholder: "*******", text: $viewModel.password, isSecure: true, autoCapitalization: .never)

            HStack {
                Button(action: { viewModel.rememberMe.toggle() }) {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.rememberMe ? "checkmark.square.fill" : "square")
                            .foregroundColor(.authGreen)
                        Text("Remember Me")
                            .font(.system(size: 14))
                            .foregroundColor(.authGreen)
                    }
                }

                Spacer()

                Button(action: { viewModel.forgotPassword() }) {
                    Text("Forgot Password")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.authGreen)
                }
            }
            .frame(width: UIConstants.Auth.formWidth)

            AuthPrimaryButton(title: "Login") {
                viewModel.login()
            }
            .padding(.top, 10)

            OrDividerView()

            SocialAuthButton(title: "Continue with Google") {
                // TODO: Google login action
            }

            Button(action: onSignupTap) {
                HStack(spacing: 4) {
                    Text("Not a Member?")
                        .foregroundColor(.authPlaceholder)
                    Text("Signup")
                        .foregroundColor(.authGreen)
                        .fontWeight(.bold)
                }
                .font(.system(size: 14))
            }
            .padding(.top, 10)
        }
        .padding(.top, 10)
        .padding(.bottom, 30)
    }
}

#Preview {
    LoginView(viewModel: LoginViewModel(), onSignupTap: {})
        .background(Color.authCream)
}
