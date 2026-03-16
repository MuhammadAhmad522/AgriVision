import SwiftUI

struct SignupView: View {
    /// `@ObservedObject` — the View observes but does not own the ViewModel;
    /// ownership lives in `AuthContainerView` which was given it by the Coordinator.
    @ObservedObject var viewModel: SignupViewModel
    var onLoginTap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            AuthTextField(label: "First Name", placeholder: "Muhammad", text: $viewModel.firstName, autoCapitalization: .words)
                .onChange(of: viewModel.firstName) { newValue in
                    viewModel.validateField(.firstName, value: newValue)
                }
            if let error = viewModel.firstNameError {
                Text(error).font(.caption).foregroundColor(.red).frame(maxWidth: .infinity, alignment: .leading)
            }

            AuthTextField(label: "Last Name", placeholder: "Ahmad", text: $viewModel.lastName, autoCapitalization: .words)
                .onChange(of: viewModel.lastName) { newValue in
                    viewModel.validateField(.lastName, value: newValue)
                }
            if let error = viewModel.lastNameError {
                Text(error).font(.caption).foregroundColor(.red).frame(maxWidth: .infinity, alignment: .leading)
            }

            AuthTextField(label: "Email", placeholder: "ahmad@mail.com", text: $viewModel.email, keyboardType: .emailAddress, autoCapitalization: .never)
                .onChange(of: viewModel.email) { newValue in
                    viewModel.validateField(.email, value: newValue)
                }
            if let error = viewModel.emailError {
                Text(error).font(.caption).foregroundColor(.red).frame(maxWidth: .infinity, alignment: .leading)
            }

            AuthTextField(label: "Password", placeholder: "*******", text: $viewModel.password, isSecure: true, autoCapitalization: .never)
                .onChange(of: viewModel.password) { newValue in
                    viewModel.validateField(.password, value: newValue)
                }
            if let error = viewModel.passwordError {
                Text(error).font(.caption).foregroundColor(.red).frame(maxWidth: .infinity, alignment: .leading)
            }

            AuthTextField(label: "Confirm Password", placeholder: "*******", text: $viewModel.confirmPassword, isSecure: true, autoCapitalization: .never)
                .onChange(of: viewModel.confirmPassword) { newValue in
                    viewModel.validateField(.confirmPassword, value: newValue)
                }
            if let error = viewModel.confirmPasswordError {
                Text(error).font(.caption).foregroundColor(.red).frame(maxWidth: .infinity, alignment: .leading)
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
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
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
    SignupView(viewModel: SignupViewModel(authService: MockAuthService()), onLoginTap: {})
        .background(Color.authCream)
}
