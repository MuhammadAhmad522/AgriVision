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


struct OnboardingView: View {
    @StateObject private var viewModel: OnboardingViewModel
    let onComplete: () -> Void

    /// Primary initializer: accepts an externally created ViewModel so the Coordinator
    /// (or a test) can own it. Using `StateObject(wrappedValue:)` ensures the ViewModel
    /// is only created once — SwiftUI ignores subsequent instances — while still allowing
    /// the caller to control creation (avoiding the eager-allocation pitfall of a default arg).
    init(viewModel: OnboardingViewModel, onComplete: @escaping () -> Void) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.onComplete = onComplete
    }

    /// Convenience initializer for SwiftUI Previews or simple call sites that don't
    /// need to own the ViewModel. The ViewModel is created lazily inside `StateObject`.
    init(onComplete: @escaping () -> Void) {
        self._viewModel = StateObject(wrappedValue: OnboardingViewModel())
        self.onComplete = onComplete
    }
    
    var body: some View {
        GeometryReader { outerGeo in
            ZStack {
                WaveBackground(scrollOffset: viewModel.scrollOffset)
                    .ignoresSafeArea()
                
                VStack {
                    HStack {
                        Spacer()
                        Button("Skip") { onComplete() }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppColors.limeGreen)
                            .padding(.trailing, 24)
                    }
                    .padding(.top, 10)
                    
                    TabView(selection: $viewModel.currentPage) {
                        ForEach(0..<viewModel.pages.count, id: \.self) { index in
                            OnboardingPageView(page: viewModel.pages[index], isFirstPage: index == 0)
                                .tag(index)
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
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .coordinateSpace(name: "OnboardingTabView")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { viewModel.handlePreferenceChange(dictionary: $0) }
    
                    VStack(spacing: 20) {
                        HStack(spacing: 8) {
                            ForEach(0..<viewModel.pages.count, id: \.self) { index in
                                Circle()
                                    .fill(viewModel.currentPage == index ? AppColors.charcoalGreen : AppColors.limeGreen.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                viewModel.handleNextAction(onComplete: onComplete)
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
                }
                .padding(.bottom, 50)
            }
            .onAppear {
                viewModel.containerWidth = outerGeo.size.width
            }
            .onChange(of: outerGeo.size.width) { newWidth in
                viewModel.containerWidth = newWidth
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
                    let blurredSize = UIConstants.Onboarding.blurredImageFrame * page.blurredImageScale
                    Image(blurredName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: blurredSize, height: blurredSize)
                        .opacity(UIConstants.Onboarding.blurredImageOpacity)
                        .blur(radius: UIConstants.Onboarding.blurredImageBlurRadius)
                        .offset(x: page.blurredImageXOffset, y: page.blurredImageYOffset)
                }
                
                // Displays either a system icon or a custom asset image.
                if page.isSystemImage {
                    Image(systemName: page.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .foregroundColor(AppColors.mediumGreen)
                } else {
                    let mainSize = UIConstants.Onboarding.mainImageFrame * page.imageScale
                    Image(page.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: mainSize, height: mainSize)
                        .offset(y: page.imageYOffset)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                }
            }
            .frame(height: UIConstants.Onboarding.imageAreaHeight)
            
            // The text content area for titles and descriptions.
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: isFirstPage ? UIConstants.Onboarding.mainTitleSize : UIConstants.Onboarding.titleSize, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.8)
                    .foregroundColor(AppColors.mediumGreen)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 30)
                
                // Only shows the description text if it's not empty.
                if !page.description.isEmpty {
                    Text(page.description)
                        .font(.system(size: UIConstants.Onboarding.descriptionSize))
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.8)
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
            .toolbar(.hidden, for: .navigationBar)
    }
}

