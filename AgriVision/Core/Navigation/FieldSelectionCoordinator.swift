import UIKit
import SwiftUI
import CoreLocation

/// Simple data structure to hold field information during the multi-screen registration process.
struct FieldSelectionData {
    let name: String
    let coordinates: [CLLocationCoordinate2D]
    let areaHa: Double?
    let cropType: String?
    let plantationDate: Date?
    let expectedHarvestDate: Date?
}

/// Manages the flow for selecting and creating agricultural fields.
final class FieldSelectionCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController

    private let authService: AuthService
    private let dataService: AgriDataService
    
    var onFieldConfirmed: (() -> Void)?
    var onCancel: (() -> Void)?

    init(navigationController: UINavigationController, authService: AuthService, dataService: AgriDataService) {
        self.navigationController = navigationController
        self.authService = authService
        self.dataService = dataService
    }

    func start() {
        showIntro()
    }
    
    private func showIntro() {
        let viewModel = AddFieldIntroViewModel(authService: authService)
        viewModel.onAddFieldTapped = { [weak self] in
            self?.showMapSelection()
        }
        
        let view = AddFieldIntroView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: view)
        navigationController.setViewControllers([hostingController], animated: true)
    }
    
    private func showMapSelection() {
        let viewModel = FieldSelectionViewModel(authService: authService, dataService: dataService)
        viewModel.onConfirmField = { [weak self] coordinates in
            self?.showFieldDetails(coordinates: coordinates)
        }
        viewModel.onCancel = { [weak self] in
            self?.onCancel?()
            self?.navigationController.popViewController(animated: true)
        }
        
        let view = FieldSelectionView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: view)
        navigationController.setNavigationBarHidden(true, animated: true)
        navigationController.pushViewController(hostingController, animated: true)
    }
    
    private func showFieldDetails(coordinates: [CLLocationCoordinate2D]) {
        let viewModel = FieldDetailsViewModel(dataService: dataService, authService: authService, coordinates: coordinates)
        
        viewModel.onSaveTriggered = { [weak self] data, shouldPairIoT in
            if shouldPairIoT {
                self?.showSensorIntegration(with: data)
            } else {
                self?.onFieldConfirmed?()
            }
        }
        
        viewModel.onBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        
        let view = FieldDetailsView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: view)
        navigationController.pushViewController(hostingController, animated: true)
    }
    
    private func showSensorIntegration(with data: FieldSelectionData) {
        let viewModel = SensorIntegrationViewModel(dataService: dataService, authService: authService, fieldData: data)
        
        viewModel.onSetupSuccess = { [weak self] in
            self?.onFieldConfirmed?()
        }
        
        viewModel.onBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        
        let view = SensorIntegrationView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: view)
        navigationController.pushViewController(hostingController, animated: true)
    }
}
