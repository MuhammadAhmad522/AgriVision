import SwiftUI

/// A reusable "OR" divider used by both `LoginView` and `SignupView`.
///
/// Extracting this into a dedicated component eliminates the duplicated
/// boilerplate that previously existed in both views (DRY principle).
struct OrDividerView: View {
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.authBorder)
                .frame(height: 1)

            Text("OR")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.authPlaceholder)

            Rectangle()
                .fill(Color.authBorder)
                .frame(height: 1)
        }
        .frame(width: UIConstants.Auth.formWidth)
    }
}
