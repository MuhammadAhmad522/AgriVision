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
                .textStyle(.captionStrong)
                .foregroundColor(Theme.Colors.primary)
                .padding(.leading, 4)
            
            HStack {
                if isSecure && !isPasswordVisible {
                    SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(Theme.Colors.textSecondary))
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(autoCapitalization)
                } else {
                    TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Theme.Colors.textSecondary))
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(autoCapitalization)
                }
                
                if isSecure {
                    Button(action: {
                        isPasswordVisible.toggle()
                    }) {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .foregroundColor(Theme.Colors.primary.opacity(0.6))
                            .frame(width: 20, height: 20)
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 50) // Slightly taller for modern look
            .background(
                ZStack {
                    VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                    Color.white.opacity(0.4)
                }
            )
            .cornerRadius(16) // Rounder
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .frame(maxWidth: UIConstants.Auth.formWidth)
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

struct ValidatedAuthTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let error: String?
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autoCapitalization: TextInputAutocapitalization = .sentences
    let onChange: (String) -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            AuthTextField(
                label: label,
                placeholder: placeholder,
                text: $text,
                isSecure: isSecure,
                keyboardType: keyboardType,
                autoCapitalization: autoCapitalization
            )
            .onChange(of: text) { newValue in
                onChange(newValue)
            }
            
            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: UIConstants.Auth.formWidth, alignment: .leading)
            }
        }
    }
}
