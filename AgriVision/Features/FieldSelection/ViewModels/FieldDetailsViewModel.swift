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
    @Published var profileImageURL: URL?
    @Published var profileInitial: String = ""
    
    // Default harvest: 4 months
    private static let defaultHarvestInterval: TimeInterval = 60 * 60 * 24 * 30 * 4
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Constants
    
    let cropTypes = ["Wheat", "Sugarcane", "Rice"]
    
    // MARK: - Dependencies
    
    private let dataService: AgriDataService
    private let authService: AuthService
    private let coordinates: [CLLocationCoordinate2D]

    private var calculatedAreaHa: Double {
        guard coordinates.count >= 3 else { return 0 }
        let earthRadiusMeters = 6_378_137.0
        let radians = Double.pi / 180
        var area = 0.0

        for index in coordinates.indices {
            let current = coordinates[index]
            let next = coordinates[(index + 1) % coordinates.count]
            var longitudeDelta = (next.longitude - current.longitude) * radians
            if longitudeDelta > Double.pi {
                longitudeDelta -= 2 * Double.pi
            } else if longitudeDelta < -Double.pi {
                longitudeDelta += 2 * Double.pi
            }
            area += longitudeDelta * (
                2
                + sin(current.latitude * radians)
                + sin(next.latitude * radians)
            )
        }

        return abs(area * earthRadiusMeters * earthRadiusMeters / 2) / 10_000
    }
    
    // MARK: - Callbacks
    
    /// Called when the user clicks 'Save'. 
    /// If IoT is ON, we only validate and pass data. 
    /// If IoT is OFF, we persist to backend.
    var onSaveTriggered: ((FieldSelectionData, Bool) -> Void)?
    var onBack: (() -> Void)?
    
    init(dataService: AgriDataService, authService: AuthService, coordinates: [CLLocationCoordinate2D]) {
        self.dataService = dataService
        self.authService = authService
        self.coordinates = coordinates
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
    
    func saveField() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a field name."
            ToastMessageAutoDismiss.schedule(
                expectedMessage: errorMessage ?? "",
                currentMessage: { [weak self] in self?.errorMessage },
                clearMessage: { [weak self] in self?.errorMessage = nil }
            )
            return
        }

        let areaHa = calculatedAreaHa
        guard (1.0...3000.0).contains(areaHa) else {
            errorMessage = areaHa < 1
                ? "Field area must be at least 1 hectare. Draw a larger boundary."
                : "Field area cannot exceed 3000 hectares. Draw a smaller boundary."
            ToastMessageAutoDismiss.schedule(
                expectedMessage: errorMessage ?? "",
                currentMessage: { [weak self] in self?.errorMessage },
                clearMessage: { [weak self] in self?.errorMessage = nil }
            )
            return
        }
        
        let data = FieldSelectionData(
            name: name,
            coordinates: coordinates,
            // The server recalculates this with PostGIS and remains authoritative.
            areaHa: areaHa,
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
                errorMessage = error.userFacingMessage
                    ToastMessageAutoDismiss.schedule(
                        expectedMessage: errorMessage ?? "",
                        currentMessage: { [weak self] in self?.errorMessage },
                        clearMessage: { [weak self] in self?.errorMessage = nil }
                    )
            }
        }
    }
    
    func goBack() {
        onBack?()
    }
    
}
