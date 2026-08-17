import SwiftUI

struct VerifyEmailView: View {
    @StateObject var viewModel: VerifyEmailViewModel
    
    init(viewModel: VerifyEmailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "envelope.badge.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(Theme.Colors.primary)
                .padding(.top, 40)
            
            Text("Verify your Email")
                .textStyle(.title2)
                .foregroundColor(Theme.Colors.primary)
            
            Text("We have sent a verification email to your address. Please click the link in the email to activate your account.")
                .textStyle(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.horizontal)
            
            if let message = viewModel.message {
                Text(message)
                    .textStyle(.caption)
                    .foregroundColor(viewModel.isVerified ? Theme.Colors.success : Theme.Colors.warning)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if viewModel.isLoading {
                ProgressView()
            } else {
                AuthPrimaryButton(title: "I've Verified My Email", isLoading: false) {
                    viewModel.checkVerificationStatus()
                }
                .padding(.top, 20)
                
                Button("Resend Email") {
                    viewModel.resendVerificationEmail()
                }
                .textStyle(.bodyStrong)
                .foregroundColor(Theme.Colors.primary)
            }
            
            Spacer()
        }
        .padding()
        .background(Theme.Colors.background.ignoresSafeArea())
    }
}

#Preview {
    VerifyEmailView(viewModel: VerifyEmailViewModel(authService: MockAuthService()))
}
