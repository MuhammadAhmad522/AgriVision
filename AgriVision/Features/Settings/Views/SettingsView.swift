import SwiftUI

/// A passive UI component that displays the user's settings options.
/// It listens to the `SettingsViewModel` for state changes like errors or success messages.
struct SettingsView: View {

    @StateObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section(header: Text("Account Integration")) {
                Button(action: {
                    viewModel.linkGoogleAccount()
                }) {
                    HStack {
                        Label("Link Google Account", systemImage: "link")
                            .foregroundStyle(AppColors.authGreen)
                        
                        Spacer()
                        
                        if viewModel.isLoading {
                            ProgressView()
                        }
                    }
                }
                .disabled(viewModel.isLoading)
            }
            
            Section {
                Button(role: .destructive, action: {
                    viewModel.signOut()
                }) {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            Group {
                if let errorMessage = viewModel.errorMessage {
                    ToastView(message: errorMessage, type: .error)
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else if let successMessage = viewModel.successMessage {
                    ToastView(message: successMessage, type: .success)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.top, 10)
            .padding(.horizontal, 16)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.errorMessage)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.successMessage)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(viewModel: SettingsViewModel(authService: MockAuthService(isLoggedIn: true)))
    }
}
