//
//  AppDelegate.swift
//  AgriVision
//
//  Created by Muhammad Ahmad on 19/01/2026.
//

import UIKit

/**
 The `AppDelegate` is the traditional entry point for an iOS application.
 It manages app-wide transitions, such as when the app finishes launching,
 or when it moves between the background and foreground.
 */
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    /**
     This is the first method called when the app starts.
     Use this for initial setup that doesn't involve the UI (e.g., configuring analytics or third-party SDKs).
     */
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    // MARK: - UISceneSession Lifecycle
    // Since iOS 13, the UI lifecycle has moved to the SceneDelegate. 
    // These methods help manage multiple windows (scenes) if the app supports them.

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new user interface instance (scene) is being created.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user closes a scene (e.g., by swiping it away in the App Switcher).
    }
}

