import SwiftUI

/// The current user's avatar (profile photo or initial), shown across onboarding and the
/// dashboard. Tapping it reveals a Sign Out action, so signing out is always reachable
/// wherever this is shown — including flows that precede having any registered fields.
struct UserAvatarView: View {
    let profileImageURL: URL?
    let profileInitial: String
    var size: CGFloat = 40
    let onSignOut: () -> Void

    var body: some View {
        Menu {
            Button(role: .destructive, action: onSignOut) {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            avatarImage
        }
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let profileImageURL {
            AsyncImage(url: profileImageURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image.resizable()
                         .aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .shadow(radius: 2)
        } else {
            ZStack {
                Circle()
                    .fill(Theme.Colors.primaryMedium)
                Text(profileInitial.isEmpty ? "U" : profileInitial)
                    .textStyle(.bodyStrong)
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .shadow(radius: 2)
        }
    }
}
