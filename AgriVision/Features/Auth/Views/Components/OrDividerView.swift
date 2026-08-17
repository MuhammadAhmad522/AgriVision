import SwiftUI

/// A reusable "OR" divider used by both `LoginView` and `SignupView`.
///
/// Extracting this into a dedicated component eliminates the duplicated
/// boilerplate that previously existed in both views (DRY principle).
struct OrDividerView: View {
    var body: some View {
        HStack {
            Rectangle()
                .fill(Theme.Colors.primaryLight.opacity(0.3)) // Updated Color
                .frame(height: 1)

            Text("OR")
                .textStyle(.captionStrong)
                .foregroundColor(Theme.Colors.primary.opacity(0.6)) // Updated Color

            Rectangle()
                .fill(Theme.Colors.primaryLight.opacity(0.3)) // Updated Color
                .frame(height: 1)
        }
        .frame(width: UIConstants.Auth.formWidth)
    }
}
