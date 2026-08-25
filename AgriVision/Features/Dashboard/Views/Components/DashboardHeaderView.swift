import SwiftUI

struct DashboardHeaderView: View {
    var userName: String
    var location: String
    var profileImageURL: URL?
    var profileInitial: String
    @Binding var showNotifications: Bool
    var notificationCount: Int
    var onSignOut: () -> Void
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Location Pill
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(Theme.Colors.primary)
                        .layoutPriority(1)
                    
                    Text(location)
                        .textStyle(.captionStrong)
                        .foregroundColor(Theme.Colors.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .layoutPriority(-1) // Allow pill to shrink if space is tight
                
                Spacer(minLength: 8)
                
                // Notification Bell
                Button(action: { showNotifications = true }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.Colors.primary)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                        
                        if notificationCount > 0 {
                            Text("\(notificationCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(5)
                                .background(Theme.Colors.error)
                                .clipShape(Circle())
                                .offset(x: 2, y: -2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .layoutPriority(1)
                
                // Avatar
                UserAvatarView(profileImageURL: profileImageURL, profileInitial: profileInitial, onSignOut: onSignOut)
                    .layoutPriority(1)
            }
            
            HStack {
                Text("Hi, \(userName)")
                    .textStyle(.title1)
                    .foregroundColor(Theme.Colors.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.8)
                Spacer()
            }
        }
    }
}
