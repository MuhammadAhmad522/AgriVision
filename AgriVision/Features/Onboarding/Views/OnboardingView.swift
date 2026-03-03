import SwiftUI

// A PreferenceKey is used to send data from a child view up to its parent.
// We use this to track the horizontal scroll position of each page.
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        // Merge the dictionaries, keeping the newest values.
        value.merge(nextValue()) { (_, new) in new }
    }
}


// This is the main view for the onboarding screens.
// It uses a TabView to let users swipe through different pages.
struct OnboardingView: View {
    // Keeps track of which page is currently being shown (0, 1, 2, etc.)
    @State private var currentPage = 0
    // Tracks the continuous scroll offset as the user swipes.
    @State private var scrollOffset: CGFloat = 0
    // Stores the actual width of the onboarding container for accurate math.
    @State private var containerWidth: CGFloat = UIScreen.main.bounds.width
    // A flag to prevent preference updates from fighting the manual animation 
    // during a programmatic button click.
    @State private var isProgrammaticChange = false
    
    // A lucky closure (function) that runs when the user finishes all onboarding steps.
    let onComplete: () -> Void
    
    // Our list of pages, each with its own title and images.
    private let pages: [OnboardingPage] = [
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
        // GeometryReader at the top level to capture the true screen/container width.
        GeometryReader { outerGeo in
            // ZStack overlays views on top of each other.
            ZStack {
                // Animated background that shifts as we change pages.
                // We pass the continuous scrollOffset so it moves smoothly during swipes.
                WaveBackground(scrollOffset: scrollOffset)
                    .ignoresSafeArea()
                
                // Main vertical container for the logic and navigation.
                VStack {
                    // Top bar with the "Skip" button.
                    HStack {
                        Spacer()
                        Button("Skip") {
                            // When skip is tapped, we skip straight to the end.
                            onComplete()
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.limeGreen)
                        .padding(.trailing, 24)
                    }
                    .padding(.top, 10)
                    
                    // The swipeable area (the core of the onboarding).
                    TabView(selection: $currentPage) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            // Create a separate view for each page's content.
                            OnboardingPageView(page: pages[index], isFirstPage: index == 0)
                                .tag(index) // Marks this page with its index for selection.
                                // We use GeometryReader to track the position of each page.
                                // This ensures we always have a valid offset during swipes.
                                .background(
                                    GeometryReader { geometry in
                                        Color.clear
                                            .preference(
                                                key: ScrollOffsetPreferenceKey.self,
                                                value: [index: geometry.frame(in: .named("OnboardingTabView")).minX]
                                            )
                                    }
                                )
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // Hides the default dots.
                    .coordinateSpace(name: "OnboardingTabView") // Define a local coordinate space.
                    // When the preference value changes (due to swiping), we update our state.
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { dictionary in
                        // If we are currently animating via a button click, we skip these updates
                        // to prevent "fighting" between the manual animation and geometry reports.
                        guard !isProgrammaticChange else { return }
                        
                        // We calculate the global scroll offset using ANY visible page.
                        // This allows the wave to follow the finger during manual swipes.
                        // The formula 'minX - (index * width)' always gives the same 'global zero' position.
                        if let (index, minX) = dictionary.first {
                            scrollOffset = minX - (CGFloat(index) * containerWidth)
                        }
                    }
                    .onChange(of: outerGeo.size.width) { newWidth in
                        // Update container width if it changed (e.g. orientation changes).
                        containerWidth = newWidth
                    }
    
                    
                    // Bottom control area: indicators and the "Next" button.
                    VStack(spacing: 20) {
                        // Custom Page Indicator (the little circles).
                        HStack(spacing: 8) {
                            ForEach(0..<pages.count, id: \.self) { index in
                                Circle()
                                    .fill(currentPage == index ? AppColors.charcoalGreen : AppColors.limeGreen.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        
                        // The circular "Next" button with a chevron icon.
                        Button(action: {
                            if currentPage < pages.count - 1 {
                                // Move to the next page.
                                // We set the flag to disable preference updates during the transition.
                                isProgrammaticChange = true
                                
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    currentPage += 1
                                    scrollOffset = -CGFloat(currentPage) * containerWidth
                                }
                                
                                // After the animation finishes, we re-enable preference updates.
                                // 0.6s gives a slight buffer for the 0.5s animation.
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    isProgrammaticChange = false
                                }
                            } else {
                                // If we're on the last page, finish the onboarding.
                                onComplete()
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


}


// A helper view that displays the content of a single onboarding page.
struct OnboardingPageView: View {
    let page: OnboardingPage
    let isFirstPage: Bool
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // The image area with optional blurred background effects.
            ZStack {
                // Shows a blurred background leaf if it exists.
                if let blurredName = page.blurredImageName {
                    Image(blurredName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: UIConstants.Onboarding.blurredImageFrame, height: UIConstants.Onboarding.blurredImageFrame)
                        .opacity(UIConstants.Onboarding.blurredImageOpacity)
                        .blur(radius: UIConstants.Onboarding.blurredImageBlurRadius)
                        .offset(x: page.imageName == "onboarding_image_3" ? 30 : -50, y: 30)
                }
                
                // Displays either a system icon or a custom asset image.
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
                        .frame(width: UIConstants.Onboarding.mainImageFrame, height: UIConstants.Onboarding.mainImageFrame)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                }
            }
            .frame(height: UIConstants.Onboarding.imageAreaHeight)
            
            // The text content area for titles and descriptions.
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: isFirstPage ? UIConstants.Onboarding.mainTitleSize : UIConstants.Onboarding.titleSize, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.mediumGreen)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 30)
                
                // Only shows the description text if it's not empty.
                if !page.description.isEmpty {
                    Text(page.description)
                        .font(.system(size: UIConstants.Onboarding.descriptionSize))
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppColors.charcoalGreen)
                        .padding(.horizontal, 40)
                }
            }
            
            Spacer()
        }
    }
}

// This allows us to preview the OnboardingView in Xcode.
#Preview {
    NavigationStack {
        OnboardingView(onComplete: {})
            .navigationBarHidden(true)
    }
}

