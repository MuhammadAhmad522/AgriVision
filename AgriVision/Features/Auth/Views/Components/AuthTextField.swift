import SwiftUI

struct AuthTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autoCapitalization: TextInputAutocapitalization = .sentences
    
    @State private var isPasswordVisible: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.authGreen)
            
            HStack {
                if isSecure && !isPasswordVisible {
                    SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(.authPlaceholder))
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(autoCapitalization)
                } else {
                    TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.authPlaceholder))
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(autoCapitalization)
                }
                
                if isSecure {
                    Button(action: {
                        isPasswordVisible.toggle()
                    }) {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .foregroundColor(.authPlaceholder)
                            .frame(width: 20, height: 20)
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(Color.authCream)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.authInputBorder, lineWidth: 1)
            )
        }
        .frame(maxWidth: 326)
    }
}

#Preview {
    VStack(spacing: 20) {
        AuthTextField(label: "First Name", placeholder: "Muhammad", text: .constant(""))
        AuthTextField(label: "Password", placeholder: "*******", text: .constant(""), isSecure: true)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
