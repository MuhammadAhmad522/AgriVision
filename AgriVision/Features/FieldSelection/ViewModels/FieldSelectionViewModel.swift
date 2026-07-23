import Foundation
import Combine
import MapKit
import SwiftUI

@MainActor
class FieldSelectionViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    /// The display name of the current location pointer.
    @Published var locationName: String = "Lahore, Punjab"
    @Published var profileImageURL: URL?
    @Published var profileInitial: String = "A"
    
    // MARK: - Search State
    
    /// The active search query typed by the user.
    /// Changes to this property are debounced before triggering a search to reduce API calls.
    @Published var searchQuery: String = ""
    @Published var searchResults: [MKLocalSearchCompletion] = []
    private var searchCompleter = MKLocalSearchCompleter()
    
    // MARK: - UI Feedback
    
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isSearching: Bool = false
    
    // MARK: - Map Data
    
    /// Ordered list of coordinates representing the user's drawn polygon.
    /// Used by the MapView to render the `MKPolygon` overlay.
    @Published var fieldCoordinates: [CLLocationCoordinate2D] = []
    
    /// The visible region of the map.
    /// This is binding-connected to the map view. Updates here move the map, and map gestures update this value.
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 31.5204, longitude: 74.3587),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    // MARK: - Dependencies
    
    private let authService: AuthService
    private let dataService: AgriDataService
    private var cancellables = Set<AnyCancellable>()
    private let locationManager = CLLocationManager()
    
    // MARK: - Actions (Coordinator Delegates)
    
    var onConfirmField: (([CLLocationCoordinate2D]) -> Void)?
    var onCancel: (() -> Void)?
    
    // MARK: - Initialization
    
    init(authService: AuthService, dataService: AgriDataService) {
        self.authService = authService
        self.dataService = dataService
        super.init()
        setupProfile()
        setupLocationManager()
        setupSearch()
    }
    
    /// Configures the search completer and observes query changes.
    /// We use a 300ms debounce to avoid spamming the local search API while typing.
    private func setupSearch() {
        searchCompleter.delegate = self
        // Optional: resultTypes = .pointOfInterest | .address
        
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                if query.isEmpty {
                    self?.searchResults = []
                } else {
                    self?.searchCompleter.queryFragment = query
                }
            }
            .store(in: &cancellables)
    }
    
    /// Configures location services for high accuracy.
    /// High accuracy is required because field boundaries need precision (meters matter).
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
    }
    
    // MARK: - Public Methods
    
    /// Displays a temporary toast message to the user.
    /// - Parameters:
    ///   - error: Error message to display (red).
    ///   - success: Success message to display (green).
    private func showMessage(error: String? = nil, success: String? = nil) {
        withAnimation {
            errorMessage = error
            successMessage = success
        }
        
        // Auto-clear after 3 seconds
        Task {
            try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
            await MainActor.run {
                withAnimation {
                    if errorMessage == error { errorMessage = nil }
                    if successMessage == success { successMessage = nil }
                }
            }
        }
    }
    
    /// Centers the map on the user's current location.
    /// If no location is available (e.g., simulator without location set), it falls back to a default location (Lahore).
    func centerOnUserLocation() {
        // If we have a real location from the manager, use it.
        if let location = locationManager.location {
            withAnimation {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                )
            }
        } else {
            // Fallback for Simulator if no location is set: Center on Lahore
            withAnimation {
                region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 31.5204, longitude: 74.3587),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
        }
    }
    
    /// Zooms the map in by reducing the span (i.e., increasing the map's zoom level).
    /// The zoom level is capped to prevent excessive zooming which could lead to crashes or empty views.
    func zoomIn() {
        var span = region.span
        // Prevent zooming in too far (e.g., 0.0001 degrees)
        guard span.latitudeDelta > 0.0001 && span.longitudeDelta > 0.0001 else { return }
        
        span.latitudeDelta *= 0.5
        span.longitudeDelta *= 0.5
        withAnimation {
            region.span = span
        }
    }
    
    /// Zooms the map out by increasing the span (i.e., decreasing the map's zoom level).
    /// The zoom level is capped at reasonable maximums to prevent crashes (Max is 180 degrees).
    func zoomOut() {
        var span = region.span
        
        // Calculate new span
        let newLatitudeDelta = span.latitudeDelta * 2
        let newLongitudeDelta = span.longitudeDelta * 2
        
        // Cap at reasonable maximums (e.g. 100 degrees) to prevent crash (Max is 180)
        if newLatitudeDelta > 100 || newLongitudeDelta > 100 {
            span.latitudeDelta = 100
            span.longitudeDelta = 100
        } else {
            span.latitudeDelta = newLatitudeDelta
            span.longitudeDelta = newLongitudeDelta
        }
        
        withAnimation {
            region.span = span
        }
    }
    
    // MARK: - Methods for map interaction
    
    /// Adds a new point to the polygon.
    /// - Parameter coordinate: The geographical coordinate of the new point.
    func addPoint(_ coordinate: CLLocationCoordinate2D) {
        fieldCoordinates.append(coordinate)
    }
    
    /// Moves an existing point to a new location.
    /// - Parameters:
    ///   - index: The index of the point to move.
    ///   - coordinate: The new geographical coordinate for the point.
    func movePoint(at index: Int, to coordinate: CLLocationCoordinate2D) {
        guard index >= 0 && index < fieldCoordinates.count else { return }
        fieldCoordinates[index] = coordinate
    }
    
    /// Undoes the last point addition or movement.
    /// Does nothing if there are no points in the polygon.
    func undoLastPoint() {
        if !fieldCoordinates.isEmpty {
            fieldCoordinates.removeLast()
        }
    }
    
    /// Clears all points from the polygon.
    /// This effectively resets the drawn field boundary.
    func clearPoints() {
        fieldCoordinates.removeAll()
    }
    
    // MARK: - Profile Setup
    
    /// Initializes the user's profile information (photo, name initial).
    /// This is displayed in the UI, typically in a profile or settings section.
    private func setupProfile() {
        if let url = authService.currentUserPhotoURL {
            self.profileImageURL = url
        }
        
        if let name = authService.currentUserDisplayName {
            let names = name.split(separator: " ")
            if let last = names.last, let firstChar = last.first {
                self.profileInitial = String(firstChar).uppercased()
            } else if let first = names.first?.first {
                self.profileInitial = String(first).uppercased()
            }
        }
    }
    
    /// Confirms the drawn field boundary and notifies the coordinator to proceed with details.
    /// - Requires at least 3 points and an area between 1 and 3000 hectares.
    func confirmField() {
        guard fieldCoordinates.count >= 3 else {
            showMessage(error: "Please define a polygon with at least 3 points.")
            return
        }

        let areaHa = calculatedAreaHa(for: fieldCoordinates)
        guard (1.0...3000.0).contains(areaHa) else {
            showMessage(
                error: areaHa < 1
                    ? "Field area must be at least 1 hectare. Draw a larger boundary."
                    : "Field area cannot exceed 3000 hectares. Draw a smaller boundary."
            )
            return
        }
        
        // Notify coordinator with the selected coordinates
        self.onConfirmField?(self.fieldCoordinates)
    }

    private func calculatedAreaHa(for coordinates: [CLLocationCoordinate2D]) -> Double {
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
    
    /// Cancels the field selection process and triggers the cancel flow.
    /// Typically used to dismiss the current view or reset the state.
    func cancelSelection() {
        onCancel?()
    }
    
    /// Moves the map to a specific location and updates the search state.
    /// - Parameters:
    ///   - coordinate: The geographical coordinate of the location.
    ///   - name: The display name of the location.
    /// - Updates:
    ///   - `region`: Centers the map on the new location.
    ///   - `locationName`: Updates the displayed name.
    ///   - `isSearching`: Hides the search results.
    ///   - `searchQuery`: Clears the search query.
    ///   - `searchResults`: Clears the previous search results.
    func moveToLocation(coordinate: CLLocationCoordinate2D, name: String) {
        withAnimation {
            region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            locationName = name
            isSearching = false
            searchQuery = "" // Clear query after selection
            searchResults = []
        }
    }
    
    /// Selects a search result and moves the map to its location.
    /// - Parameter completion: The search result to select.
    /// - Performs a local search to resolve the coordinates of the selected result.
    /// - Moves the map to the resolved coordinates.
    /// - Updates the location name and clears the search state.
    func selectSearchResult(_ completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        
        search.start { [weak self] response, error in
            guard let self = self else { return }
            guard let coordinate = response?.mapItems.first?.placemark.coordinate else {
                self.showMessage(error: "Could not find location coordinates.")
                return
            }
            
            self.moveToLocation(coordinate: coordinate, name: completion.title)
        }
    }
}

// MARK: - MKLocalSearchCompleterDelegate
extension FieldSelectionViewModel: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.searchResults = completer.results
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error: \(error.localizedDescription)")
    }
}

// MARK: - CLLocationManagerDelegate
extension FieldSelectionViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // We don't necessarily want to follow the user around (it snaps the map)
        // but we want to make sure the manager HAS the latest location for when they tap "Locate Me"
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location Manager Error: \(error.localizedDescription)")
        if let clError = error as? CLError, clError.code == .denied {
            showMessage(error: "Location access denied. Please enable it in Settings.")
        } else {
            showMessage(error: "Failed to determine location.")
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            showMessage(error: "Location access denied. Some features may not work.")
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }
}
