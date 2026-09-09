import SwiftUI

struct BackendConnectionView: View {
    let message: String
    let isRetrying: Bool
    let onRetry: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "server.rack")
                .textStyle(.display)
                .foregroundStyle(Theme.Colors.primaryMedium)
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
            .tint(Theme.Colors.primaryMedium)
            .disabled(isRetrying)
            Button("Sign Out", role: .destructive, action: onSignOut)
        }
        .padding(32)
    }
}
