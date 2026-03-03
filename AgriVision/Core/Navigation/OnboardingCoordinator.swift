import UIKit
import SwiftUI

/// Coordinator responsible for managing the onboarding flow.
class OnboardingCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController
    
    /// Closure called when the onboarding process is finished.
    var onFinished: (() -> Void)?
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    func start() {
        let view = OnboardingView(onComplete: { [weak self] in
            self?.onFinished?()
        })
        let hostingController = UIHostingController(rootView: view)
        navigationController.setViewControllers([hostingController], animated: true)
    }
}
