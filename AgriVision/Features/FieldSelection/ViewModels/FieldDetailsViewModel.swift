import Foundation
import Combine
import CoreLocation

@MainActor
class FieldDetailsViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var name: String = ""
    @Published var selectedCrop: String = "Wheat"
    @Published var plantationDate: Date = Date()
    @Published var harvestDate: Date = Date().addingTimeInterval(60 * 60 * 24 * 30 * 4) // 4 months default
    @Published var monitorWithIoT: Bool = false
    
    // Default harvest: 4 months
    private static let defaultHarvestInterval: TimeInterval = 60 * 60 * 24 * 30 * 4
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Constants
    
    let cropTypes = ["Wheat", "Maize", "Cotton", "Sugarcane", "Rice", "Potatoes"]
    
    // MARK: - Dependencies
    
    private let dataService: AgriDataService
    private let coordinates: [CLLocationCoordinate2D]
    
    // MARK: - Callbacks
    
    /// Called when the user clicks 'Save'. 
    /// If IoT is ON, we only validate and pass data. 
    /// If IoT is OFF, we persist to backend.
    var onSaveTriggered: ((FieldSelectionData, Bool) -> Void)?
    var onBack: (() -> Void)?
    
    init(dataService: AgriDataService, coordinates: [CLLocationCoordinate2D]) {
        self.dataService = dataService
        self.coordinates = coordinates
    }
    
    // MARK: - Actions
    
    func saveField() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a field name."
            return
        }
        
        let data = FieldSelectionData(
            name: name,
            coordinates: coordinates,
            areaHa: calculateArea(),
            cropType: selectedCrop,
            plantationDate: plantationDate,
            expectedHarvestDate: harvestDate
        )
        
        if monitorWithIoT {
            // Defer saving until sensor pairing is complete
            onSaveTriggered?(data, true)
        } else {
            // Save immediately
            performSave(data: data)
        }
    }
    
    private func performSave(data: FieldSelectionData) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await dataService.saveField(
                    name: data.name,
                    coordinates: data.coordinates,
                    areaHa: data.areaHa,
                    cropType: data.cropType,
                    plantationDate: data.plantationDate,
                    expectedHarvestDate: data.expectedHarvestDate,
                    sensors: nil
                )
                
                isLoading = false
                onSaveTriggered?(data, false)
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func goBack() {
        onBack?()
    }
    
    // MARK: - Helpers
    
    private func calculateArea() -> Double {
        // Logic to calculate area from coordinates could go here
        // For simplicity, we'll return a placeholder or 0.0
        return 0.0
    }
}
