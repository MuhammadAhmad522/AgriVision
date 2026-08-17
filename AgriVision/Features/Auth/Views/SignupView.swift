import SwiftUI

struct SignupView: View {
    /// `@ObservedObject` — the View observes but does not own the ViewModel;
    /// ownership lives in `AuthContainerView` which was given it by the Coordinator.
    @ObservedObject var viewModel: SignupViewModel
    var onLoginTap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ValidatedAuthTextField(label: "First Name", placeholder: "Muhammad", text: $viewModel.firstName, error: viewModel.firstNameError, autoCapitalization: .words) { newValue in
                viewModel.validateField(.firstName, value: newValue)
            }

            ValidatedAuthTextField(label: "Last Name", placeholder: "Ahmad", text: $viewModel.lastName, error: viewModel.lastNameError, autoCapitalization: .words) { newValue in
                viewModel.validateField(.lastName, value: newValue)
            }

            ValidatedAuthTextField(label: "Email", placeholder: "ahmad@mail.com", text: $viewModel.email, error: viewModel.emailError, keyboardType: .emailAddress, autoCapitalization: .never) { newValue in
                viewModel.validateField(.email, value: newValue)
            }

            ValidatedAuthTextField(label: "Password", placeholder: "*******", text: $viewModel.password, error: viewModel.passwordError, isSecure: true, autoCapitalization: .never) { newValue in
                viewModel.validateField(.password, value: newValue)
            }

            ValidatedAuthTextField(label: "Confirm Password", placeholder: "*******", text: $viewModel.confirmPassword, error: viewModel.confirmPasswordError, isSecure: true, autoCapitalization: .never) { newValue in
                viewModel.validateField(.confirmPassword, value: newValue)
            }

            AuthPrimaryButton(title: "Register", isLoading: viewModel.isLoading) {
                viewModel.register()
            }
            .padding(.top, 10)

            OrDividerView()

            SocialAuthButton(title: "Continue with Google") {
                viewModel.continueWithGoogle()
            }
            .disabled(viewModel.isLoading)
            .opacity(viewModel.isLoading ? 0.6 : 1.0)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .textStyle(.caption)
                    .foregroundColor(Theme.Colors.error)
                    .padding(.horizontal)
            }

            Button(action: onLoginTap) {
                HStack(spacing: 4) {
                    Text("Already a Member?")
                        .foregroundColor(Theme.Colors.textSecondary)
                    Text("Login")
                        .foregroundColor(Theme.Colors.primary)
                        .fontWeight(.bold)
                }
                .textStyle(.captionStrong)
            }
            .padding(.bottom, 20)
        }
        .padding(.top, 10)
        .padding(.bottom, 30)
    }
}

#Preview {
    SignupView(viewModel: SignupViewModel(authService: MockAuthService(), userProfileService: MockUserProfileService()), onLoginTap: {})
        .background(Theme.Colors.background)
}
