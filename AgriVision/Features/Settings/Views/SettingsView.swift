import SwiftUI

/// A passive UI component that displays the user's settings options.
/// It listens to the `SettingsViewModel` for state changes like errors or success messages.
struct SettingsView: View {

    @StateObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background
            Color(AppColors.cream).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Account Integration Card
                    GlassCard(title: "Account Integration") {
                        Button(action: {
                            viewModel.linkGoogleAccount()
                        }) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 36, height: 36)
                                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                    
                                    Image(systemName: "link")
                                        .foregroundColor(AppColors.mediumGreen)
                                        .font(.system(size: 16))
                                }
                                
                                Text("Link Google Account")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(AppColors.charcoalGreen)
                                
                                Spacer()
                                
                                if viewModel.isLoading {
                                    ProgressView()
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(AppColors.limeGreen)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .disabled(viewModel.isLoading)
                    }
                    
                    // Sign Out Card
                    GlassCard {
                        Button(role: .destructive, action: {
                            viewModel.signOut()
                        }) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(Color.red.opacity(0.1))
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .foregroundColor(.red)
                                        .font(.system(size: 16))
                                }
                                
                                Text("Sign Out")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.red)
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding()
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
