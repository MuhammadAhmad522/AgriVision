import UIKit
import SwiftUI

/// `DashboardCoordinator` owns the navigation flow for the Dashboard feature.
///
/// Extracting this from `AppCoordinator` satisfies the Single Responsibility Principle (SRP):
/// `AppCoordinator` is now only responsible for the top-level app flow (Splash → Onboarding → Auth → Dashboard),
/// while `DashboardCoordinator` owns everything that happens *inside* the Dashboard.
///
/// The injected `AgriDataService` satisfies the Dependency Inversion Principle (DIP): the
/// coordinator depends on a protocol abstraction rather than a concrete repository type.
final class DashboardCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController

    private let dataService: AgriDataService
    private let authService: AuthService
    private let preferencesService: PreferencesService
    
    var onSignOut: (() -> Void)?

    init(navigationController: UINavigationController, dataService: AgriDataService, authService: AuthService, preferencesService: PreferencesService) {
        self.navigationController = navigationController
        self.dataService = dataService
        self.authService = authService
        self.preferencesService = preferencesService
    }

    func start() {
        // At startup, we check if the user has any fields registered.
        // If not, we guide them through the "Add Field" flow.
        Task {
            do {
                let fields = try await dataService.fetchFields()
                
                await MainActor.run {
                    if fields.isEmpty {
                        showAddFieldIntro()
                    } else {
                        showDashboard()
                    }
                }
            } catch {
                // If we can't fetch (maybe network error), fallback to dashboard 
                // which handles its own error states.
                await MainActor.run {
                    showDashboard()
                }
            }
        }
    }
    
    private func showAddFieldIntro() {
        let fieldSelectionCoordinator = FieldSelectionCoordinator(
            navigationController: navigationController, 
            authService: authService,
            dataService: dataService
        )
        
        fieldSelectionCoordinator.onFieldConfirmed = { [weak self, weak fieldSelectionCoordinator] in
            guard let self = self, let coordinator = fieldSelectionCoordinator else { return }
            self.childCoordinators.removeAll { $0 === coordinator }
            self.showDashboard()
        }
        
        fieldSelectionCoordinator.onCancel = { [weak self, weak fieldSelectionCoordinator] in
            guard let self = self, let coordinator = fieldSelectionCoordinator else { return }
            self.childCoordinators.removeAll { $0 === coordinator }
            // If they cancel adding their FIRST field, we might still want to show an empty dashboard
            // or return to where they were. For now, show dashboard.
            self.showDashboard()
        }
        
        childCoordinators.append(fieldSelectionCoordinator)
        fieldSelectionCoordinator.start()
    }

    private func showDashboard() {
        let viewModel = DashboardViewModel(
            dataService: dataService, 
            authService: authService
        )
        viewModel.onSignOut = { [weak self] in
            self?.onSignOut?()
        }
        viewModel.onSettingsTap = { [weak self] in
            self?.showSettings()
        }
        viewModel.onSettingsTap = { [weak self] in
            self?.showSettings()
        }
        viewModel.onChatTapped = { [weak self] fieldId in
            self?.showChat(for: fieldId)
        }
        
        let view = DashboardView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: view)
        
        // Show the navigation bar for the dashboard
        navigationController.setNavigationBarHidden(false, animated: true)
        navigationController.navigationBar.prefersLargeTitles = true
        
        // Use push if we came from Intro, or setViewControllers if replacing
        // If we want to allow "Back" (unlikely for dashboard), use setViewControllers to reset stack
        navigationController.setViewControllers([hostingController], animated: true)
    }

    private func showSettings() {
        let settingsCoordinator = SettingsCoordinator(
            navigationController: navigationController,
            authService: authService,
            dataService: dataService,
            preferencesService: preferencesService
        )
        
        settingsCoordinator.onSignOut = { [weak self] in
            self?.onSignOut?()
            // When signing out from settings, we want to pop everything
            self?.navigationController.popToRootViewController(animated: false)
        }
        
        settingsCoordinator.onFinished = { [weak self, weak settingsCoordinator] in
            guard let self = self, let coordinator = settingsCoordinator else { return }
            self.childCoordinators.removeAll { $0 === coordinator }
        }
        
        childCoordinators.append(settingsCoordinator)
        settingsCoordinator.start()
    }
    
    private func showChat(for fieldId: UUID) {
        let chatViewModel = AIChatViewModel(dataService: dataService, fieldId: fieldId)
        
        let chatView = AIChatView(viewModel: chatViewModel)
        let hostingController = UIHostingController(rootView: chatView)
        hostingController.modalPresentationStyle = .pageSheet
        
        chatViewModel.onDismiss = { [weak hostingController] in
            hostingController?.dismiss(animated: true)
        }
        
        navigationController.present(hostingController, animated: true)
    }
}
