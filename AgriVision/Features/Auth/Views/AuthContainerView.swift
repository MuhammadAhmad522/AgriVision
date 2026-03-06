import SwiftUI

struct AuthContainerView: View {
    @State private var selectedTab: AuthTab = .signup
    
    var body: some View {
        ZStack {
            // Background Image
            Image("bg-image")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            // Glassmorphic Card container
            ScrollView(showsIndicators: false) {
                VStack {
                    Spacer(minLength: 60)
                    
                    VStack(spacing: 20) {
                        // Tab Toggle
                        AuthTabToggle(selectedTab: $selectedTab)
                            .padding(.top, 25)
                        
                        // Forms
                        ZStack {
                            if selectedTab == .login {
                                LoginView {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        selectedTab = .signup
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                            } else {
                                SignupView {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        selectedTab = .login
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .frame(width: 371)
                    .background(
                        RoundedRectangle(cornerRadius: 50)
                            .fill(Color.white.opacity(0.1))
                            .background(
                                Color.white.opacity(0.1)
                                    .blur(radius: 20)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 50)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 50))
                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
                    
                    Spacer(minLength: 60)
                }
                .frame(minHeight: UIScreen.main.bounds.height)
            }
        }
        .onTapGesture {
            // Dismiss keyboard when tapping away from input fields
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

#Preview {
    AuthContainerView()
}
