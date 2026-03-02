import SwiftUI

struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let imageName: String
    let blurredImageName: String? // Optional blurred layer
    let isSystemImage: Bool
}

struct OnboardingView: View {
    @State private var currentPage = 0
    
    let pages = [
      
        OnboardingPage(
            title: "AgriVision",
            description: "",
            imageName: "onboarding_leaf",
            blurredImageName: "onboarding_leaf_blurred",
            isSystemImage: false
        ),
        OnboardingPage(
            title: "Map Your Fields.\nGet Smart Alerts and AI Insights.",
            description: "",
            imageName: "onboarding_leaf_2",
            blurredImageName: "onboarding_leaf_2_blurred",
            isSystemImage: false
        ),
        OnboardingPage(
            title: "Analyze soil, crop health, and field conditions using advanced satellite, IOT sensor and AI technology.",
            description: "",
            imageName: "onboarding_image_3",
            blurredImageName: "onboarding_image_3_blurred",
            isSystemImage: false
        )
    ]
    
    var body: some View {
        ZStack {
            WaveBackground(currentPage: currentPage)
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Button("Skip") {
                        // Handle skip
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.limeGreen)
                    .padding(.trailing, 24)
                }
                .padding(.top, 10)
                
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index], isFirstPage: index == 0)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                VStack(spacing: 20) {
                    // Page Indicator
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? AppColors.charcoalGreen : AppColors.limeGreen.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    // Next Button
                    Button(action: {
                        if currentPage < pages.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            // Finish onboarding
                        }
                    }) {
                        Image(systemName: "chevron.right.2")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppColors.mediumGreen)
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .shadow(color: AppColors.mediumGreen.opacity(0.3), radius: 4, x: 0, y: 4)
                            )
                    }
                }
                .padding(.bottom, 50)
            }
        }
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    let isFirstPage: Bool
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Image Area
            ZStack {
                // Optional blurred background leaf (high-fidelity SVG)
                if let blurredName = page.blurredImageName {
                    Image(blurredName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 520, height: 520) // Larger spread for the 'luminous' glow
                        .opacity(0.9)
                        .blur(radius: 20) // Extra softening for 'shades of light' feel
                        .offset(x: page.imageName == "onboarding_image_3" ? 30 : 0, y: 0) // Centered, but shifted right for Page 3
                }
                
                if page.isSystemImage {
                    Image(systemName: page.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .foregroundColor(AppColors.mediumGreen)
                } else {
                    Image(page.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 320, height: 320)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                }
            }
            .frame(height: 400)
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: isFirstPage ? 60 : 22, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.mediumGreen)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 30)
                
                if !page.description.isEmpty {
                    Text(page.description)
                        .font(.system(size: 18))
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppColors.charcoalGreen)
                        .padding(.horizontal, 40)
                }
            }
            
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
}
