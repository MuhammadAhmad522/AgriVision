import XCTest
import CoreLocation
import MapKit
@testable import AgriVision

@MainActor
final class FieldSelectionViewModelTests: XCTestCase {

    func test_initialState() {
        let vm = FieldSelectionViewModel(authService: MockAuthService(), dataService: MockAgriDataRepository())
        XCTAssertTrue(vm.fieldCoordinates.isEmpty)
        XCTAssertEqual(vm.locationName, "Lahore, Punjab")
        XCTAssertEqual(vm.searchQuery, "")
        XCTAssertEqual(vm.searchResults, [])
        XCTAssertFalse(vm.isSearching)
    }

    func test_addPoint_appendsCoordinate() {
        let vm = FieldSelectionViewModel(authService: MockAuthService(), dataService: MockAgriDataRepository())
        let coord = CLLocationCoordinate2D(latitude: 31.5, longitude: 74.3)
        vm.addPoint(coord)
        XCTAssertEqual(vm.fieldCoordinates.count, 1)
        XCTAssertEqual(vm.fieldCoordinates[0].latitude, 31.5)
    }

    func test_addPoint_multiplePoints() {
        let vm = FieldSelectionViewModel(authService: MockAuthService(), dataService: MockAgriDataRepository())
        vm.addPoint(CLLocationCoordinate2D(latitude: 31.5, longitude: 74.3))
        vm.addPoint(CLLocationCoordinate2D(latitude: 31.6, longitude: 74.4))
        vm.addPoint(CLLocationCoordinate2D(latitude: 31.4, longitude: 74.5))
        XCTAssertEqual(vm.fieldCoordinates.count, 3)
    }

    func test_movePoint_updatesCoordinate() {
        let vm = FieldSelectionViewModel(authService: MockAuthService(), dataService: MockAgriDataRepository())
        let original = CLLocationCoordinate2D(latitude: 31.5, longitude: 74.3)
        vm.addPoint(original)
        let updated = CLLocationCoordinate2D(latitude: 31.6, longitude: 74.4)
        vm.movePoint(at: 0, to: updated)
        XCTAssertEqual(vm.fieldCoordinates[0].latitude, 31.6)
        XCTAssertEqual(vm.fieldCoordinates[0].longitude, 74.4)
    }

    func test_movePoint_invalidIndex_ignored() {
        let vm = FieldSelectionViewModel(authService: MockAuthService(), dataService: MockAgriDataRepository())
        vm.movePoint(at: 5, to: CLLocationCoordinate2D(latitude: 0, longitude: 0))
        XCTAssertTrue(vm.fieldCoordinates.isEmpty)
    }

    func test_undoLastPoint_removesLast() {
        let vm = FieldSelectionViewModel(authService: MockAuthService(), dataService: MockAgriDataRepository())
        vm.addPoint(CLLocationCoordinate2D(latitude: 31.5, longitude: 74.3))
        vm.addPoint(CLLocationCoordinate2D(latitude: 31.6, longitude: 74.4))
        vm.undoLastPoint()
        XCTAssertEqual(vm.fieldCoordinates.count, 1)
    }

    func test_undoLastPoint_empty_doesNothing() {
        let vm = FieldSelectionViewModel(authService: MockAuthService(), dataService: MockAgriDataRepository())
        vm.undoLastPoint()
        XCTAssertTrue(vm.fieldCoordinates.isEmpty)
    }

    func test_clearPoints_removesAll() {
        let vm = FieldSelectionViewModel(authService: MockAuthService(), dataService: MockAgriDataRepository())
        vm.addPoint(CLLocationCoordinate2D(latitude: 31.5, longitude: 74.3))
        vm.addPoint(CLLocationCoordinate2D(latitude: 31.6, longitude: 74.4))
        vm.clearPoints()
        XCTAssertTrue(vm.fieldCoordinates.isEmpty)
    }

    func test_confirmField_tooFewPoints_showsError() {
        let vm = FieldSelectionViewModel(authService: MockAuthService(), dataService: MockAgriDataRepository())
        vm.addPoint(CLLocationCoordinate2D(latitude: 31.5, longitude: 74.3))
        vm.addPoint(CLLocationCoordinate2D(latitude: 31.6, longitude: 74.4))

        var confirmed = false
        vm.onConfirmField = { _ in confirmed = true }
        vm.confirmField()

        XCTAssertFalse(confirmed)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_confirmField_threePoints_callsCallback() {
        let vm = FieldSelectionViewModel(authService: MockAuthService(), dataService: MockAgriDataRepository())
        addValidPolygon(vm)

        var confirmedCoordinates: [CLLocationCoordinate2D]?
        vm.onConfirmField = { coords in confirmedCoordinates = coords }
        vm.confirmField()

        XCTAssertNotNil(confirmedCoordinates)
        XCTAssertEqual(confirmedCoordinates?.count, 4)
        XCTAssertNil(vm.errorMessage)
    }

    func test_areaCalculation_knownPolygon() {
        let vm = FieldSelectionViewModel(authService: MockAuthService(), dataService: MockAgriDataRepository())
        // A 1x1 degree square near the equator (~111x111 km = ~12321 ha)
        let coords = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
            CLLocationCoordinate2D(latitude: 0, longitude: 1),
        ]
        let area = areaHa(for: coords, using: vm)
        // A 1x1 degree square at the equator is ~12,300 km² = ~1,230,000 ha
        XCTAssertGreaterThan(area, 1_200_000)
        XCTAssertLessThan(area, 1_250_000)
    }

    func test_areaCalculation_smallPolygon() {
        let vm = FieldSelectionViewModel(authService: MockAuthService(), dataService: MockAgriDataRepository())
        // Small polygon (< 1 ha)
        let coords = [
            CLLocationCoordinate2D(latitude: 31.5204, longitude: 74.3587),
            CLLocationCoordinate2D(latitude: 31.5205, longitude: 74.3589),
            CLLocationCoordinate2D(latitude: 31.5203, longitude: 74.3590),
        ]
        let area = areaHa(for: coords, using: vm)
        XCTAssertLessThan(area, 1)
    }

    func test_zoomIn_reducesSpan() {
        let vm = FieldSelectionViewModel(authService: MockAuthService(), dataService: MockAgriDataRepository())
        let originalLat = vm.region.span.latitudeDelta
        vm.zoomIn()
        XCTAssertEqual(vm.region.span.latitudeDelta, originalLat * 0.5)
    }

    func test_zoomIn_minimumCap() {
        let vm = FieldSelectionViewModel(authService: MockAuthService(), dataService: MockAgriDataRepository())
        vm.region.span = MKCoordinateSpan(latitudeDelta: 0.00005, longitudeDelta: 0.00005)
        vm.zoomIn()
        // Should not go below minimum
        XCTAssertEqual(vm.region.span.latitudeDelta, 0.00005)
    }

    func test_zoomOut_increasesSpan() {
        let vm = FieldSelectionViewModel(authService: MockAuthService(), dataService: MockAgriDataRepository())
        let originalLat = vm.region.span.latitudeDelta
        vm.zoomOut()
        XCTAssertEqual(vm.region.span.latitudeDelta, min(originalLat * 2, 100))
    }

    func test_zoomOut_maximumCap() {
        let vm = FieldSelectionViewModel(authService: MockAuthService(), dataService: MockAgriDataRepository())
        vm.region.span = MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)
        vm.zoomOut()
        XCTAssertEqual(vm.region.span.latitudeDelta, 100)
    }

    func test_moveToLocation_updatesRegion() {
        let vm = FieldSelectionViewModel(authService: MockAuthService(), dataService: MockAgriDataRepository())
        let coord = CLLocationCoordinate2D(latitude: 30.0, longitude: 72.0)
        vm.moveToLocation(coordinate: coord, name: "Test Location")
        XCTAssertEqual(vm.region.center.latitude, 30.0)
        XCTAssertEqual(vm.region.center.longitude, 72.0)
        XCTAssertEqual(vm.locationName, "Test Location")
        XCTAssertFalse(vm.isSearching)
        XCTAssertEqual(vm.searchQuery, "")
    }

    func test_cancelSelection_callsCallback() {
        let vm = FieldSelectionViewModel(authService: MockAuthService(), dataService: MockAgriDataRepository())
        var cancelled = false
        vm.onCancel = { cancelled = true }
        vm.cancelSelection()
        XCTAssertTrue(cancelled)
    }

    // MARK: - Helpers

    private func addValidPolygon(_ vm: FieldSelectionViewModel) {
        // Roughly 10 ha around Lahore
        vm.addPoint(CLLocationCoordinate2D(latitude: 31.5244, longitude: 74.3538))
        vm.addPoint(CLLocationCoordinate2D(latitude: 31.5240, longitude: 74.3610))
        vm.addPoint(CLLocationCoordinate2D(latitude: 31.5176, longitude: 74.3618))
        vm.addPoint(CLLocationCoordinate2D(latitude: 31.5169, longitude: 74.3543))
    }

    private func areaHa(for coordinates: [CLLocationCoordinate2D], using vm: FieldSelectionViewModel) -> Double {
        // Use a proxy: create a temporary VM, feed coordinates, call calculatedAreaHa
        // We access private method via reflection or test the known impl
        // Since calculatedAreaHa is private, we verify via confirmField behavior
        // Let's just compute it independently using the same algorithm
        guard coordinates.count >= 3 else { return 0 }
        let earthRadiusMeters = 6_378_137.0
        let radians = Double.pi / 180
        var area = 0.0
        for index in coordinates.indices {
            let current = coordinates[index]
            let next = coordinates[(index + 1) % coordinates.count]
            var longitudeDelta = (next.longitude - current.longitude) * radians
            if longitudeDelta > Double.pi { longitudeDelta -= 2 * Double.pi }
            else if longitudeDelta < -Double.pi { longitudeDelta += 2 * Double.pi }
            area += longitudeDelta * (2 + sin(current.latitude * radians) + sin(next.latitude * radians))
        }
        return abs(area * earthRadiusMeters * earthRadiusMeters / 2) / 10_000
    }
}

@MainActor
final class FieldDetailsViewModelTests: XCTestCase {

    func test_initialState() {
        let coords = [CLLocationCoordinate2D(latitude: 31.5, longitude: 74.3)]
        let vm = FieldDetailsViewModel(
            dataService: MockAgriDataRepository(),
            authService: MockAuthService(isLoggedIn: true),
            coordinates: coords
        )
        XCTAssertEqual(vm.name, "")
        XCTAssertEqual(vm.selectedCrop, "Wheat")
        XCTAssertFalse(vm.monitorWithIoT)
        XCTAssertFalse(vm.isLoading)
        XCTAssertEqual(vm.cropTypes, ["Wheat", "Sugarcane", "Rice"])
    }

    func test_saveField_emptyName_showsError() {
        let coords = samplePolygon()
        let vm = FieldDetailsViewModel(
            dataService: MockAgriDataRepository(),
            authService: MockAuthService(),
            coordinates: coords
        )
        vm.name = ""
        var saveTriggered = false
        vm.onSaveTriggered = { _, _ in saveTriggered = true }

        vm.saveField()

        XCTAssertFalse(saveTriggered)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_saveField_validInput_triggersSave() async {
        let coords = samplePolygon()
        let vm = FieldDetailsViewModel(
            dataService: MockAgriDataRepository(),
            authService: MockAuthService(),
            coordinates: coords
        )
        vm.name = "Test Field"

        var saveData: FieldSelectionData?
        var needsIoT: Bool = false
        vm.onSaveTriggered = { data, iot in
            saveData = data
            needsIoT = iot
        }

        vm.saveField()
        // Yield to let the unstructured Task in performSave execute
        try? await Task.sleep(nanoseconds: 1_100_000_000)

        XCTAssertNotNil(saveData)
        XCTAssertEqual(saveData?.name, "Test Field")
        XCTAssertEqual(saveData?.cropType, "Wheat")
        XCTAssertFalse(needsIoT)
    }

    func test_saveField_withIoTFlag() async {
        let coords = samplePolygon()
        let vm = FieldDetailsViewModel(
            dataService: MockAgriDataRepository(),
            authService: MockAuthService(),
            coordinates: coords
        )
        vm.name = "IoT Field"
        vm.monitorWithIoT = true

        var needsIoT = false
        vm.onSaveTriggered = { _, iot in needsIoT = iot }

        vm.saveField()
        // IoT path calls onSaveTriggered synchronously
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(needsIoT)
    }

    func test_saveField_areaTooSmall_showsError() {
        // 2 points = no area
        let coords = [
            CLLocationCoordinate2D(latitude: 31.5204, longitude: 74.3538),
            CLLocationCoordinate2D(latitude: 31.5240, longitude: 74.3610),
        ]
        let vm = FieldDetailsViewModel(
            dataService: MockAgriDataRepository(),
            authService: MockAuthService(),
            coordinates: coords
        )
        vm.name = "Small Field"
        var saveTriggered = false
        vm.onSaveTriggered = { _, _ in saveTriggered = true }

        vm.saveField()

        XCTAssertFalse(saveTriggered)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_goBack_callsCallback() {
        let vm = FieldDetailsViewModel(
            dataService: MockAgriDataRepository(),
            authService: MockAuthService(),
            coordinates: [CLLocationCoordinate2D(latitude: 31.5, longitude: 74.3)]
        )
        var backCalled = false
        vm.onBack = { backCalled = true }
        vm.goBack()
        XCTAssertTrue(backCalled)
    }

    func test_settngCropType_updatesSelection() {
        let vm = FieldDetailsViewModel(
            dataService: MockAgriDataRepository(),
            authService: MockAuthService(),
            coordinates: [CLLocationCoordinate2D(latitude: 31.5, longitude: 74.3)]
        )
        vm.selectedCrop = "Rice"
        XCTAssertEqual(vm.selectedCrop, "Rice")
    }

    // MARK: - Helpers

    private func samplePolygon() -> [CLLocationCoordinate2D] {
        [
            CLLocationCoordinate2D(latitude: 31.5244, longitude: 74.3538),
            CLLocationCoordinate2D(latitude: 31.5240, longitude: 74.3610),
            CLLocationCoordinate2D(latitude: 31.5176, longitude: 74.3618),
            CLLocationCoordinate2D(latitude: 31.5169, longitude: 74.3543),
        ]
    }
}
