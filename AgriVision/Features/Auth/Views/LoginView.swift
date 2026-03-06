import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var rememberMe = false
    
    var onSignupTap: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            AuthTextField(label: "Email", placeholder: "ahmad@mail.com", text: $email, keyboardType: .emailAddress, autoCapitalization: .never)
            
            AuthTextField(label: "Password", placeholder: "*******", text: $password, isSecure: true, autoCapitalization: .never)
            
            HStack {
                Button(action: {
                    rememberMe.toggle()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                            .foregroundColor(.authGreen)
                        Text("Remember Me")
                            .font(.system(size: 14))
                            .foregroundColor(.authGreen)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    // Forgot password action
                }) {
                    Text("Forgot Password")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.authGreen)
                }
            }
            .frame(width: 326)
            
            AuthPrimaryButton(title: "Login") {
                // Login action
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
    LoginView(onSignupTap: {})
        .background(Color.authCream)
}
