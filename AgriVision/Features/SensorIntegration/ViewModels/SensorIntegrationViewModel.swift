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
    
    // MARK: - Constants
    
    let sensorTypes = ["Multi-Sensor", "Soil Moisture", "Temperature Hub", "Weather Station"]
    
    // MARK: - Dependencies
    
    private let dataService: AgriDataService
    private let fieldData: FieldSelectionData
    
    // MARK: - Callbacks
    
    var onSetupSuccess: (() -> Void)?
    var onBack: (() -> Void)?
    
    init(dataService: AgriDataService, fieldData: FieldSelectionData) {
        self.dataService = dataService
        self.fieldData = fieldData
    }
    
    // MARK: - Actions
    
    func verifyHardware() {
        guard !pairingCode.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a Pairing Code to verify."
            return
        }
        
        isVerifying = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await dataService.verifySensorConnection(deviceId: pairingCode)
                isVerified = result.isVerified
                verificationMessage = result.message
                if !result.isVerified {
                    errorMessage = result.message
                }
                isVerifying = false
            } catch {
                isVerified = false
                isVerifying = false
                errorMessage = "Verification failed: \(error.localizedDescription)"
            }
        }
    }
    
    func completeSetup() {
        guard isVerified else {
            errorMessage = "Please verify your hardware connection first."
            return
        }
        
        guard !sensorName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please give your sensor hub a name (e.g., 'West Field ESP')."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Assembly: Field + Sensors (ESP32)
                let sensors = [
                    SensorConfig(
                        deviceId: pairingCode, 
                        name: sensorName,
                        sensorType: "esp32_multi_sensor"
                    )
                ]
                
                _ = try await dataService.saveField(
                    name: fieldData.name,
                    coordinates: fieldData.coordinates,
                    areaHa: fieldData.areaHa,
                    cropType: fieldData.cropType,
                    plantationDate: fieldData.plantationDate,
                    expectedHarvestDate: fieldData.expectedHarvestDate,
                    sensors: sensors
                )
                
                isLoading = false
                onSetupSuccess?()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func goBack() {
        onBack?()
    }
}
