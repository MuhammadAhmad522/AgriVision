import UIKit

/**
 A `Coordinator` is responsible for managing the navigation flow in the app.
 By using Coordinators, we keep our Views (screens) and ViewModels clean,
 because they don't have to worry about "where to go next" or "how to show the next screen."
 */
protocol Coordinator: AnyObject {
    
    /// A list of "child" coordinators. If a coordinator opens a new complex flow (like a checkout process),
    /// it might create a child coordinator to handle it. We keep them in this array so they aren't removed from memory.
    var childCoordinators: [Coordinator] { get set }
    
    /// The actual navigation controller that pushes and pops screens on iOS.
    /// The coordinator uses this to show the views on the screen.
    var navigationController: UINavigationController { get set }
    
    /// This method is called to begin the coordinator's flow.
    /// Usually, it creates the first view and pushes it onto the `navigationController`.
    func start()
}

