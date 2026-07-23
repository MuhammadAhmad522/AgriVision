import Foundation
import Combine

@MainActor
class SensorIntegrationViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var sensorName: String = ""
    @Published var selectedSensorType: String = "Multi-Sensor"
    @Published var pairingCode: String = ""
    
    @Published var isLoading: Bool = false
    @Published var isVerifying: Bool = false
    @Published var isVerified: Bool = false
    @Published var errorMessage: String?
    @Published var verificationMessage: String?
    @Published var profileImageURL: URL?
    @Published var profileInitial: String = ""
    
    // MARK: - Constants
    
    let sensorTypes = ["Multi-Sensor", "Soil Moisture", "Temperature Hub", "Weather Station"]
    
    // MARK: - Dependencies
    
    private let dataService: AgriDataService
    private let authService: AuthService
    private let fieldData: FieldSelectionData
    private var createdFieldID: UUID?
    
    // MARK: - Callbacks
    
    var onSetupSuccess: (() -> Void)?
    var onBack: (() -> Void)?
    
    init(dataService: AgriDataService, authService: AuthService, fieldData: FieldSelectionData) {
        self.dataService = dataService
        self.authService = authService
        self.fieldData = fieldData
        loadUserData()
    }
    
    /// Loads the current user's profile data (photo URL and name initial)
    private func loadUserData() {
        self.profileImageURL = authService.currentUserPhotoURL
        
        if let displayName = authService.currentUserDisplayName, !displayName.isEmpty {
            let components = displayName.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ")
            
            if components.count > 1, let last = components.last, let firstChar = last.first {
                self.profileInitial = String(firstChar).uppercased()
            } else if let firstComponent = components.first, let firstChar = firstComponent.first {
                self.profileInitial = String(firstChar).uppercased()
            }
        } else {
            self.profileInitial = "U"
        }
    }
    
    // MARK: - Actions
    
    func verifyHardware() {
        guard !pairingCode.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a Pairing Code to verify."
            ToastMessageAutoDismiss.schedule(
                expectedMessage: errorMessage ?? "",
                currentMessage: { self.errorMessage },
                clearMessage: { self.errorMessage = nil }
            )
            return
        }
        
        isVerifying = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await dataService.pairSensor(deviceId: pairingCode)
                isVerified = result.isPaired
                verificationMessage = result.message
                if !result.isPaired {
                    errorMessage = result.message
                    ToastMessageAutoDismiss.schedule(
                        expectedMessage: errorMessage ?? "",
                        currentMessage: { self.errorMessage },
                        clearMessage: { self.errorMessage = nil }
                    )
                }
                isVerifying = false
            } catch {
                isVerified = false
                isVerifying = false
                errorMessage = error.userFacingMessage
                ToastMessageAutoDismiss.schedule(
                    expectedMessage: errorMessage ?? "",
                    currentMessage: { self.errorMessage },
                    clearMessage: { self.errorMessage = nil }
                )
            }
        }
    }
    
    func completeSetup() {
        guard isVerified else {
            errorMessage = "Please pair your sensor first."
            ToastMessageAutoDismiss.schedule(
                expectedMessage: errorMessage ?? "",
                currentMessage: { self.errorMessage },
                clearMessage: { self.errorMessage = nil }
            )
            return
        }
        
        guard !sensorName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please give your sensor hub a name (e.g., 'West Field ESP')."
            ToastMessageAutoDismiss.schedule(
                expectedMessage: errorMessage ?? "",
                currentMessage: { self.errorMessage },
                clearMessage: { self.errorMessage = nil }
            )
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fieldID: UUID
                if let createdFieldID {
                    fieldID = createdFieldID
                } else {
                    let field = try await dataService.saveField(
                        name: fieldData.name,
                        coordinates: fieldData.coordinates,
                        areaHa: fieldData.areaHa,
                        cropType: fieldData.cropType,
                        plantationDate: fieldData.plantationDate,
                        expectedHarvestDate: fieldData.expectedHarvestDate,
                        sensors: nil
                    )
                    createdFieldID = field.id
                    fieldID = field.id
                }

                try await dataService.assignSensor(
                    SensorConfig(
                        deviceId: pairingCode,
                        name: sensorName,
                        sensorType: "esp32_multi_sensor"
                    ),
                    to: fieldID
                )
                
                isLoading = false
                onSetupSuccess?()
            } catch {
                isLoading = false
                errorMessage = error.userFacingMessage
                ToastMessageAutoDismiss.schedule(
                    expectedMessage: errorMessage ?? "",
                    currentMessage: { self.errorMessage },
                    clearMessage: { self.errorMessage = nil }
                )
            }
        }
    }
    
    func goBack() {
        onBack?()
    }
}
