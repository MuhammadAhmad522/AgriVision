import SwiftUI

/// `ErrorView` is a reusable UI component used to display network or operational errors.
/// It features branding-consistent design with a retry action.
struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Animated Error Icon
                ZStack {
                    Circle()
                        .fill(Theme.Colors.warning.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .textStyle(.display)
                        .foregroundColor(Theme.Colors.warning)
                }
                .padding(.top, 40)
                
                VStack(spacing: 12) {
                    Text("Connection Issue")
                        .textStyle(.title2)
                        .foregroundColor(Theme.Colors.primary)
                    
                    Text(message)
                        .textStyle(.body)
                        .foregroundColor(Theme.Colors.primary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                    .frame(height: 20)
                
                // Retry Button
                Button(action: onRetry) {
                    Text("Retry")
                        .textStyle(.bodyStrong)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Theme.Colors.primaryMedium, Theme.Colors.primaryLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Theme.Colors.primaryMedium.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 40)
                
                // Secondary Dismiss/Cancel Option
                Button(action: { /* Optional: Navigate back */ }) {
                    Text("Go Back")
                        .textStyle(.bodyStrong)
                        .foregroundColor(Theme.Colors.primary.opacity(0.6))
                }
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    ErrorView(message: "We couldn't reach our servers. Please check your internet connection and try again.") {
        print("Retry tapped")
    }
}
