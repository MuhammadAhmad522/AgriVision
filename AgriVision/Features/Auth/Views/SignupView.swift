import SwiftUI

struct SignupView: View {
    /// `@ObservedObject` — the View observes but does not own the ViewModel;
    /// ownership lives in `AuthContainerView` which was given it by the Coordinator.
    @ObservedObject var viewModel: SignupViewModel
    var onLoginTap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            AuthTextField(label: "First Name", placeholder: "Muhammad", text: $viewModel.firstName, autoCapitalization: .words)

            AuthTextField(label: "Last Name", placeholder: "Ahmad", text: $viewModel.lastName, autoCapitalization: .words)

            AuthTextField(label: "Email", placeholder: "ahmad@mail.com", text: $viewModel.email, keyboardType: .emailAddress, autoCapitalization: .never)

            AuthTextField(label: "Password", placeholder: "*******", text: $viewModel.password, isSecure: true, autoCapitalization: .never)

            AuthTextField(label: "Confirm Password", placeholder: "*******", text: $viewModel.confirmPassword, isSecure: true, autoCapitalization: .never)

            AuthPrimaryButton(title: "Register") {
                viewModel.register()
            }
            .padding(.top, 10)

            OrDividerView()

            SocialAuthButton(title: "Continue with Google") {
                // TODO: Google login action
            }

            Button(action: onLoginTap) {
                HStack(spacing: 4) {
                    Text("Already a Member?")
                        .foregroundColor(.authPlaceholder)
                    Text("Login")
                        .foregroundColor(.authGreen)
                        .fontWeight(.bold)
                }
                .font(.system(size: 14))
            }
            .padding(.bottom, 20)
        }
        .padding(.top, 10)
        .padding(.bottom, 30)
    }
}

#Preview {
    SignupView(viewModel: SignupViewModel(), onLoginTap: {})
        .background(Color.authCream)
}
