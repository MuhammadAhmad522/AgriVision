import SwiftUI

struct AddFieldIntroView: View {
    @StateObject var viewModel: AddFieldIntroViewModel
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            // Figma Design Base: 402 x 874
            let designWidth: CGFloat = 402
            let designHeight: CGFloat = 874
            
            let wRatio = width / designWidth
            let hRatio = height / designHeight
            
            ZStack(alignment: .top) {
                // 1. Background Image
                Image("bg-image")
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .ignoresSafeArea()
                
                // 2. Liquid Glass Overlay (New)
                // Recreates the visual glass effect from Figma
                ZStack {
                    // Fill with gradient and blend mode
                    LinearGradient(
                        colors: [
                            Color(red: 250/255, green: 250/255, blue: 250/255).opacity(0.7),
                            Color(red: 38/255, green: 38/255, blue: 38/255)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .blendMode(.colorDodge)
                    
                    // Blur layer
                    Color(red: 0, green: 0, blue: 0, opacity: 0.08)
                        .blendMode(.hardLight)
                        .blur(radius: 20)
                }
                .frame(width: width, height: height)
                // Note: backdrop-filter: blur(40px) is best simulated with material in SwiftUI
                // but since we are layering, we can use a material view if desired,
                // or just the color overlay which gives the tint.
                // Adding an ultraThinMaterial over the *entire* bg makes it very blurry.
                // The Figma CSS shows this effect is applied to a layer covering the screen.
                
                // 3 & 4. Image Group (Blurred Glow + Sharp Image)
                ZStack {
                    // Blurred Glow
                    // CSS: Width 489. CenterY 458.5
                    Image("add_field_image_blurred")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 550 * wRatio, height: 550 * wRatio)
                        .blur(radius: 40)
                        .opacity(0.6)
                        // Offset relative to the sharp image center
                        // Blur Center Y (458.5) - Sharp Center Y (453.5) = +5px
                        .offset(y: 100 * wRatio) // Use wRatio for small internal offsets to keep shape consistent

                    // Sharp Image
                    // CSS: Width 405. CenterY 453.5
                    Image("add_field_image")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 405 * wRatio, height: 405 * wRatio)
                }
                // Position based on the Main (Sharp) Image Center
                // CSS Left: 50% + 4.5px. CSS Top: 251px. Center Y: 251 + 202.5 = 453.5
                .position(x: (width / 2) + (4.5 * wRatio), y: 453.5 * hRatio)
                
                // 5. Content Overlay
                // Top Bar - Only Profile Icon, no location bar
                HStack {
                    Spacer()
                    
                    if let url = viewModel.profileImageURL {
                        // Google User Profile Image
                        AsyncImage(url: url) { phase in
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
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .shadow(radius: 2)
                        
                    } else {
                        // Email User - Last Name Initial
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.primaryLight) // Use a brand color bg
                            
                            Text(viewModel.profileInitial)
                                .textStyle(.bodyStrong)
                                .foregroundColor(.white)
                        }
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .shadow(radius: 2)
                    }
                }
                .padding(.horizontal, 20)
                .position(x: width / 2, y: 60 + 20) // Approx top safe area + offset
                
                // Text Group
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hi, \(viewModel.userName)")
                        .textStyle(.title1) // Enlarged from 30
                        .foregroundColor(Theme.Colors.primary)
                        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
                    
                    Text("Lets Setup Your\nFarm Dashboard")
                        .textStyle(.title1) // Enlarged from 30
                        .foregroundColor(Theme.Colors.primary)
                        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
                        .lineLimit(2)
                }
                .frame(width: width - 80, alignment: .leading) // 40px padding each side
                // Moved upwards: from (181 + 50) to (150 + 50) -> slightly higher
                .position(x: width / 2, y: (150 + 50) * hRatio)
                
                // Action Button
                // Figma: Top 643
                Button(action: {
                    viewModel.addFieldAction()
                }) {
                    Text("Add Your First Field")
                        .textStyle(.bodyStrong)
                        .foregroundColor(.white)
                        .frame(width: 326 * wRatio, height: 60)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Theme.Colors.primaryLight, Theme.Colors.primaryMedium]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(32)
                        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 4)
                }
                .position(x: width / 2, y: (643 + 30) * hRatio)
                
                // Bottom Text
                Text("Get started managing your crops in minutes")
                    .textStyle(.captionStrong)
                    .foregroundColor(Theme.Colors.primary)
                    .multilineTextAlignment(.center)
                    .frame(width: 248 * wRatio, height: 32)
                    .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
                    .position(x: width / 2, y: (785 + 16) * hRatio)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    AddFieldIntroView(viewModel: AddFieldIntroViewModel(authService: MockAuthService(isLoggedIn: true)))
}
