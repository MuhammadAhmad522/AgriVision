import SwiftUI

struct ForgotPasswordView: View {
    @StateObject var viewModel: ForgotPasswordViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Custom Navigation Bar
            HStack {
                Button(action: {
                    viewModel.back()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(AppColors.authGreen)
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            Text("Forgot Password")
                .font(.largeTitle)
                .bold()
                .foregroundColor(AppColors.charcoalGreen)
                .padding(.top, 10)
            
            Text("Enter your email address to receive a password reset link.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            AuthTextField(
                label: "Email",
                placeholder: "ahmad@mail.com",
                text: $viewModel.email,
                keyboardType: .emailAddress,
                autoCapitalization: .never
            )
            .frame(width: UIConstants.Auth.formWidth)
            
            if let success = viewModel.successMessage {
                Text(success)
                    .foregroundColor(AppColors.mediumGreen)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            AuthPrimaryButton(title: "Send Reset Link", isLoading: viewModel.isLoading) {
                viewModel.sendResetLink()
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .padding(.horizontal)
        .background(Color.authCream.ignoresSafeArea())
    }
}

#Preview {
    ForgotPasswordView(viewModel: ForgotPasswordViewModel(authService: MockAuthService()))
}
