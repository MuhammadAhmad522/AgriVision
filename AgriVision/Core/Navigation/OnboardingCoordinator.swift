import UIKit
import SwiftUI

/// Coordinator responsible for managing the onboarding flow.
final class OnboardingCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController

    /// Closure called when the onboarding process is finished.
    var onFinished: (() -> Void)?

    /// Retaining the ViewModel here ensures the Coordinator controls its lifecycle and
    /// makes it easy to inject or inspect in tests. The View's `@StateObject` will keep
    /// the same instance alive for the duration of the screen.
    private var viewModel: OnboardingViewModel?

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {
        let vm = OnboardingViewModel()
        self.viewModel = vm
        let view = OnboardingView(viewModel: vm, onComplete: { [weak self] in
            self?.onFinished?()
        })
        let hostingController = UIHostingController(rootView: view)
        navigationController.setViewControllers([hostingController], animated: true)
    }
}


