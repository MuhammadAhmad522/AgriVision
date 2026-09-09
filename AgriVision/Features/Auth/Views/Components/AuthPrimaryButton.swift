import SwiftUI

struct AuthPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void
    
    var body: some View {
        AgriButton(title: title, style: .primary, isLoading: isLoading, action: action)
            .frame(width: UIConstants.Auth.formWidth)
    }
}

#Preview {
    VStack {
        AuthPrimaryButton(title: "Login") {
            print("Button tapped")
        }
        AuthPrimaryButton(title: "Loading...", isLoading: true) {
            print("Button tapped")
        }
    }
    .padding()
}
