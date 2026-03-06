import SwiftUI

struct SignupView: View {
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    var onLoginTap: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            AuthTextField(label: "First Name", placeholder: "Muhammad", text: $firstName, autoCapitalization: .words)
            
            AuthTextField(label: "Last Name", placeholder: "Ahmad", text: $lastName, autoCapitalization: .words)
            
            AuthTextField(label: "Email", placeholder: "ahmad@mail.com", text: $email, keyboardType: .emailAddress, autoCapitalization: .never)
            
            AuthTextField(label: "Password", placeholder: "*******", text: $password, isSecure: true, autoCapitalization: .never)
            
            AuthTextField(label: "Confirm Password", placeholder: "*******", text: $confirmPassword, isSecure: true, autoCapitalization: .never)
            
            AuthPrimaryButton(title: "Register") {
                // Register action
            }
            .padding(.top, 10)
            
            HStack {
                Rectangle().fill(Color.authBorder).frame(height: 1)
                Text("OR")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.authPlaceholder)
                Rectangle().fill(Color.authBorder).frame(height: 1)
            }
            .frame(width: 326)
            
            SocialAuthButton(title: "Continue with Google") {
                // Google login action
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
    SignupView(onLoginTap: {})
        .background(Color.authCream)
}
