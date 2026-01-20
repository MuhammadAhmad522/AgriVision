import UIKit
import SwiftUI

class AppCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController
    
    private let window: UIWindow
    
    init(window: UIWindow) {
        self.window = window
        self.navigationController = UINavigationController()
    }
    
    func start() {
        showMain()
        
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
    }
    
    private func showMain() {
        let dataService = MockAgriDataRepository()
        let viewModel = DashboardViewModel(dataService: dataService)
        let view = DashboardView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: view)
        navigationController.setViewControllers([hostingController], animated: false)
    }
}
