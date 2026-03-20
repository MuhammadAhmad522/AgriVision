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
                .foregroundColor(AppColors.authGreen)
                .padding(.top, 40)
            
            Text("Verify your Email")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.charcoalGreen)
            
            Text("We have sent a verification email to your address. Please click the link in the email to activate your account.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            if let message = viewModel.message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(viewModel.isVerified ? AppColors.mediumGreen : .orange)
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
                .font(.subheadline)
                .foregroundColor(AppColors.authGreen)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.authCream.ignoresSafeArea())
    }
}

#Preview {
    VerifyEmailView(viewModel: VerifyEmailViewModel(authService: MockAuthService()))
}
