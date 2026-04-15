import SwiftUI

/// `ErrorView` is a reusable UI component used to display network or operational errors.
/// It features branding-consistent design with a retry action.
struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        ZStack {
            AppColors.cream
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Animated Error Icon
                ZStack {
                    Circle()
                        .fill(AppColors.warningOrange.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(AppColors.warningOrange)
                }
                .padding(.top, 40)
                
                VStack(spacing: 12) {
                    Text("Connection Issue")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppColors.charcoalGreen)
                    
                    Text(message)
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.charcoalGreen.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                    .frame(height: 20)
                
                // Retry Button
                Button(action: onRetry) {
                    Text("Retry")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [AppColors.mediumGreen, AppColors.limeGreen],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: AppColors.mediumGreen.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 40)
                
                // Secondary Dismiss/Cancel Option
                Button(action: { /* Optional: Navigate back */ }) {
                    Text("Go Back")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.charcoalGreen.opacity(0.6))
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
