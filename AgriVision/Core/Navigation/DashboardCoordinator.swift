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
    private let fieldSessionStore: FieldSessionStore
    
    var onSignOut: (() -> Void)?

    init(navigationController: UINavigationController, dataService: AgriDataService, authService: AuthService, preferencesService: PreferencesService, fieldSessionStore: FieldSessionStore) {
        self.navigationController = navigationController
        self.dataService = dataService
        self.authService = authService
        self.preferencesService = preferencesService
        self.fieldSessionStore = fieldSessionStore
    }

    func start() {
        // At startup, we check if the user has any fields registered.
        // If not, we guide them through the "Add Field" flow.
        Task {
            await MainActor.run {
                if self.fieldSessionStore.fields.isEmpty {
                    showAddFieldIntro()
                } else {
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
            Task {
                try? await self.fieldSessionStore.refresh()
                await MainActor.run { self.showDashboard() }
            }
        }
        
        fieldSelectionCoordinator.onCancel = {
            // No-op: Map cancel pops back to AddFieldIntro screen within the same coordinator flow
        }
        
        childCoordinators.append(fieldSelectionCoordinator)
        fieldSelectionCoordinator.start()
    }

    private func showDashboard() {
        let viewModel = DashboardViewModel(
            dataService: dataService, 
            authService: authService,
            preferencesService: preferencesService,
            fieldSessionStore: fieldSessionStore
        )
        let settingsViewModel = SettingsViewModel(
            authService: authService,
            dataService: dataService,
            preferencesService: preferencesService,
            fieldSessionStore: fieldSessionStore
        )

        viewModel.onSignOut = { [weak self] in
            self?.onSignOut?()
        }
        viewModel.onSettingsTap = { [weak self] in
            self?.showSettings()
        }
        viewModel.onChatTapped = { [weak self] fieldId in
            self?.showChat(for: fieldId)
        }

        settingsViewModel.onSignOut = { [weak self] in
            self?.onSignOut?()
        }
        settingsViewModel.onFieldsEmptied = { [weak self] in
            self?.navigationController.setViewControllers([], animated: false)
            self?.showAddFieldIntro()
        }
        viewModel.onAddFieldTapped = { [weak self] in self?.showAddFieldSheet() }
        
        let view = DashboardView(
            viewModel: viewModel,
            settingsViewModel: settingsViewModel
        )
        let hostingController = UIHostingController(rootView: view)
        
        // Show the navigation bar for the dashboard
        navigationController.setNavigationBarHidden(false, animated: true)
        navigationController.navigationBar.prefersLargeTitles = true
        
        // Use push if we came from Intro, or setViewControllers if replacing
        // If we want to allow "Back" (unlikely for dashboard), use setViewControllers to reset stack
        navigationController.setViewControllers([hostingController], animated: true)
    }

    private func showAddFieldSheet() {
        guard !fieldSessionStore.hasReachedLimit else { return }
        let modalNavigation = UINavigationController()
        let coordinator = FieldSelectionCoordinator(navigationController: modalNavigation, authService: authService, dataService: dataService)
        coordinator.onFieldConfirmed = { [weak self, weak coordinator] in
            guard let self else { return }
            Task {
                try? await self.fieldSessionStore.refresh()
                await MainActor.run {
                    modalNavigation.dismiss(animated: true)
                    if let coordinator { self.childCoordinators.removeAll { $0 === coordinator } }
                }
            }
        }
        coordinator.onCancel = { modalNavigation.dismiss(animated: true) }
        childCoordinators.append(coordinator)
        coordinator.start()
        navigationController.present(modalNavigation, animated: true)
    }

    private func showSettings() {
        let settingsCoordinator = SettingsCoordinator(
            navigationController: navigationController,
            authService: authService,
            dataService: dataService,
            preferencesService: preferencesService,
            fieldSessionStore: fieldSessionStore
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
        
        settingsCoordinator.onFieldsEmptied = { [weak self, weak settingsCoordinator] in
            guard let self = self, let coordinator = settingsCoordinator else { return }
            self.childCoordinators.removeAll { $0 === coordinator }
            // Clear navigation stack and redirect to "Add Field" flow again
            self.navigationController.setViewControllers([], animated: false)
            self.showAddFieldIntro()
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
        
        var presenter: UIViewController = navigationController
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        presenter.present(hostingController, animated: true)
    }
}
