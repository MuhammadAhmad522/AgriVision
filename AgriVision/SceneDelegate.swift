//
//  SceneDelegate.swift
//  AgriVision
//
//  Created by Muhammad Ahmad on 19/01/2026.
//

import UIKit
import SwiftUI

/**
 The `SceneDelegate` manages the UI lifecycle for a specific window or "scene."
 This is where we set up the app's initial view hierarchy and navigation.
 */
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    
    /// The `AppCoordinator` is the "brain" of our navigation. 
    /// It decides which screen to show first and handles transitions between them.
    var appCoordinator: AppCoordinator?

    /**
     This method is called when a new window (scene) is about to be displayed.
     We use it to initialize our main window and start our navigation flow.
     */
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // 1. Ensure the scene being passed is a UIWindowScene (the standard for iOS apps)
        guard let windowScene = scene as? UIWindowScene else { return }

        // 2. Create a new UIWindow to hold our app's content, sized correctly to the screen
        let window = UIWindow(windowScene: windowScene)
        window.frame = windowScene.coordinateSpace.bounds
        self.window = window
        
        // 3. Build concrete service implementations at the composition root and inject them.
        //    This is the only place in the runtime app where concrete service implementations
        //    are chosen; everywhere else depends on protocols (Dependency Inversion Principle).
        let onboardingStateService = UserDefaultsOnboardingStateService()
        let dataService = MockAgriDataRepository()

        let coordinator = AppCoordinator(
            window: window,
            onboardingStateService: onboardingStateService,
            dataService: dataService
        )
        self.appCoordinator = coordinator
        
        // 4. Tell the coordinator to start, which will set up the first screen (Dashboard).
        coordinator.start()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called when the system releases the scene (e.g., app is suspended).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the app moves to the foreground and starts interacting with the user.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the app is about to move to the background (e.g., user gets a phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the app transitions from the background back to the foreground.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the app moves into the background. Save data or release resources here.
    }
}
