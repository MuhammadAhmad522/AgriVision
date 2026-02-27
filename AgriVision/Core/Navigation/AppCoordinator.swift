import UIKit
import SwiftUI

/**
 \`AppCoordinator\` is the "main boss" or root coordinator for the entire application.
 Its job is to set up the very first screen the user sees when the app launches.
 */
class AppCoordinator: Coordinator {
    
    // Conforming to the Coordinator protocol
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController
    
    /// The main window of the application where all user interface is drawn.
    private let window: UIWindow
    
    /// We initialize the AppCoordinator with the app's main window.
    init(window: UIWindow) {
        self.window = window
        self.navigationController = UINavigationController()
    }
    
    /// This is where the magic happens. Calling \`start()\` kicks off the app's UI.
    func start() {
        // 1. Setup the first screen (the Dashboard)
        showMain()
        
        // 2. We tell the main window to use our \`navigationController\` as the root.
        window.rootViewController = navigationController
        
        // 3. Make the window visible on the device screen.
        window.makeKeyAndVisible()
    }
    
    /// A private helper method used to build and display the Dashboard screen.
    private func showMain() {
        // Step 1: Create the Data Service (Repository). Right now, it gives mock (fake) data.
        let dataService = MockAgriDataRepository()
        
        // Step 2: Create the ViewModel. We give the ViewModel the data service so it can fetch data.
        let viewModel = DashboardViewModel(dataService: dataService)
        
        // Step 3: Create the View. We give the View the ViewModel so they can talk to each other.
        let view = DashboardView(viewModel: viewModel)
        
        // Step 4: Because \`DashboardView\` is a SwiftUI view, we need a "wrapper" (UIHostingController)
        // so our UIKit-based navigation controller knows how to show it.
        let hostingController = UIHostingController(rootView: view)
        
        // Step 5: Place the hosting controller into the navigation stack.
        navigationController.setViewControllers([hostingController], animated: false)
    }
}
