import SwiftUI

struct BackendConnectionView: View {
    let message: String
    let isRetrying: Bool
    let onRetry: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "server.rack")
                .font(.system(size: 52))
                .foregroundStyle(AppColors.mediumGreen)
            Text("Connecting to AgriVision")
                .font(.title2.bold())
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(action: onRetry) {
                if isRetrying { ProgressView().frame(maxWidth: .infinity) }
                else { Text("Retry").frame(maxWidth: .infinity) }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.mediumGreen)
            .disabled(isRetrying)
            Button("Sign Out", role: .destructive, action: onSignOut)
        }
        .padding(32)
    }
}
