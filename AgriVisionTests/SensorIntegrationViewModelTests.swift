import XCTest
import CoreLocation
@testable import AgriVision

@MainActor
final class SensorIntegrationViewModelTests: XCTestCase {

    func test_initialState() {
        let fieldData = FieldSelectionData(
            name: "Test Field",
            coordinates: [CLLocationCoordinate2D(latitude: 31.5, longitude: 74.3)],
            areaHa: 10,
            cropType: "Wheat",
            plantationDate: Date(),
            expectedHarvestDate: Date()
        )
        let vm = SensorIntegrationViewModel(
            dataService: MockAgriDataRepository(),
            authService: MockAuthService(isLoggedIn: true),
            fieldData: fieldData
        )
        XCTAssertEqual(vm.sensorName, "")
        XCTAssertEqual(vm.selectedSensorType, "Multi-Sensor")
        XCTAssertEqual(vm.pairingCode, "")
        XCTAssertFalse(vm.isLoading)
        XCTAssertFalse(vm.isVerifying)
        XCTAssertFalse(vm.isVerified)
        XCTAssertEqual(vm.sensorTypes, ["Multi-Sensor", "Soil Moisture", "Temperature Hub", "Weather Station"])
    }

    func test_verifyHardware_emptyCode_showsError() {
        let vm = SensorIntegrationViewModel(
            dataService: MockAgriDataRepository(),
            authService: MockAuthService(isLoggedIn: true),
            fieldData: FieldSelectionData(name: "F", coordinates: [], areaHa: 1, cropType: nil, plantationDate: nil, expectedHarvestDate: nil)
        )
        vm.pairingCode = ""

        vm.verifyHardware()

        XCTAssertFalse(vm.isVerifying)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_verifyHardware_espCode_verifies() {
        let vm = SensorIntegrationViewModel(
            dataService: MockAgriDataRepository(),
            authService: MockAuthService(isLoggedIn: true),
            fieldData: FieldSelectionData(name: "F", coordinates: [], areaHa: 1, cropType: nil, plantationDate: nil, expectedHarvestDate: nil)
        )
        vm.pairingCode = "ESP32_001"

        vm.verifyHardware()

        let exp = expectation(description: "verify hardware")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { exp.fulfill() }
        wait(for: [exp], timeout: 3)

        XCTAssertTrue(vm.isVerified)
        XCTAssertFalse(vm.isVerifying)
    }

    func test_verifyHardware_nonEspCode_fails() {
        let vm = SensorIntegrationViewModel(
            dataService: MockAgriDataRepository(),
            authService: MockAuthService(isLoggedIn: true),
            fieldData: FieldSelectionData(name: "F", coordinates: [], areaHa: 1, cropType: nil, plantationDate: nil, expectedHarvestDate: nil)
        )
        vm.pairingCode = "ARD_001"

        vm.verifyHardware()

        let exp = expectation(description: "verify hardware fail")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { exp.fulfill() }
        wait(for: [exp], timeout: 3)

        XCTAssertFalse(vm.isVerified)
        XCTAssertFalse(vm.isVerifying)
    }

    func test_completeSetup_withoutVerification_showsError() {
        let vm = SensorIntegrationViewModel(
            dataService: MockAgriDataRepository(),
            authService: MockAuthService(isLoggedIn: true),
            fieldData: FieldSelectionData(name: "F", coordinates: [], areaHa: 1, cropType: nil, plantationDate: nil, expectedHarvestDate: nil)
        )

        vm.completeSetup()

        XCTAssertFalse(vm.isLoading)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_completeSetup_withoutName_showsError() {
        let vm = SensorIntegrationViewModel(
            dataService: MockAgriDataRepository(),
            authService: MockAuthService(isLoggedIn: true),
            fieldData: FieldSelectionData(name: "F", coordinates: [], areaHa: 1, cropType: nil, plantationDate: nil, expectedHarvestDate: nil)
        )
        vm.isVerified = true
        vm.sensorName = ""

        vm.completeSetup()

        XCTAssertFalse(vm.isLoading)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_completeSetup_withValidInput_saves() {
        let vm = SensorIntegrationViewModel(
            dataService: MockAgriDataRepository(),
            authService: MockAuthService(isLoggedIn: true),
            fieldData: FieldSelectionData(name: "Test Field", coordinates: [CLLocationCoordinate2D(latitude: 31.5, longitude: 74.3)], areaHa: 10, cropType: "Wheat", plantationDate: Date(), expectedHarvestDate: Date())
        )
        vm.isVerified = true
        vm.sensorName = "Sensor 1"
        vm.pairingCode = "ESP32_001"

        var successCalled = false
        vm.onSetupSuccess = { successCalled = true }

        vm.completeSetup()

        let exp = expectation(description: "complete setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { exp.fulfill() }
        wait(for: [exp], timeout: 3)

        XCTAssertTrue(successCalled)
        XCTAssertFalse(vm.isLoading)
    }

    func test_goBack_callsCallback() {
        let vm = SensorIntegrationViewModel(
            dataService: MockAgriDataRepository(),
            authService: MockAuthService(isLoggedIn: true),
            fieldData: FieldSelectionData(name: "F", coordinates: [], areaHa: 1, cropType: nil, plantationDate: nil, expectedHarvestDate: nil)
        )
        var backCalled = false
        vm.onBack = { backCalled = true }
        vm.goBack()
        XCTAssertTrue(backCalled)
    }

    // MARK: - Error path tests

    func test_verifyHardware_serviceFailure_showsError() {
        let mockData = MockAgriDataRepository()
        mockData.shouldFail = true
        let vm = SensorIntegrationViewModel(
            dataService: mockData,
            authService: MockAuthService(isLoggedIn: true),
            fieldData: FieldSelectionData(name: "F", coordinates: [], areaHa: 1, cropType: nil, plantationDate: nil, expectedHarvestDate: nil)
        )
        vm.pairingCode = "ESP32_001"

        vm.verifyHardware()

        let exp = expectation(description: "verify hardware failure")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { exp.fulfill() }
        wait(for: [exp], timeout: 3)

        XCTAssertFalse(vm.isVerified)
        XCTAssertFalse(vm.isVerifying)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_completeSetup_serviceFailure_showsError() {
        let mockData = MockAgriDataRepository()
        mockData.shouldFail = true
        let vm = SensorIntegrationViewModel(
            dataService: mockData,
            authService: MockAuthService(isLoggedIn: true),
            fieldData: FieldSelectionData(name: "Test Field", coordinates: [CLLocationCoordinate2D(latitude: 31.5, longitude: 74.3)], areaHa: 10, cropType: "Wheat", plantationDate: Date(), expectedHarvestDate: Date())
        )
        vm.isVerified = true
        vm.sensorName = "Sensor 1"
        vm.pairingCode = "ESP32_001"

        var successCalled = false
        vm.onSetupSuccess = { successCalled = true }

        vm.completeSetup()

        let exp = expectation(description: "complete setup failure")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { exp.fulfill() }
        wait(for: [exp], timeout: 3)

        XCTAssertFalse(successCalled)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNotNil(vm.errorMessage)
    }
}
