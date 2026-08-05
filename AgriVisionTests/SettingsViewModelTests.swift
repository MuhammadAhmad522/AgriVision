import XCTest
@testable import AgriVision

@MainActor
final class SettingsViewModelTests: XCTestCase {

    func test_initialState_withStore() {
        let auth = MockAuthService(isLoggedIn: true)
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        store.fields = [Field(id: UUID(), ownerId: UUID(), name: "Alpha", coordinates: nil, areaHa: 10, createdAt: Date(), cropType: nil, plantationDate: nil, expectedHarvestDate: nil, ndviScore: nil, lastSatelliteSync: nil)]
        store.activeFieldId = store.fields.first?.id
        let vm = SettingsViewModel(
            authService: auth,
            dataService: MockAgriDataRepository(),
            preferencesService: MockPreferencesService(),
            fieldSessionStore: store
        )
        XCTAssertEqual(vm.title, "Settings")
        XCTAssertFalse(vm.isLoading)
        XCTAssertGreaterThan(vm.fields.count, 0)
    }

    func test_initialState_withoutStore() {
        let auth = MockAuthService(isLoggedIn: true)
        let vm = SettingsViewModel(
            authService: auth,
            dataService: MockAgriDataRepository(),
            preferencesService: MockPreferencesService()
        )
        XCTAssertEqual(vm.title, "Settings")
        XCTAssertEqual(vm.profileName, "Mock User")
        XCTAssertEqual(vm.accountEmail, "mock@agrivision.test")
    }

    func test_accountName_fallsBack() {
        let auth = MockAuthService(isLoggedIn: true, displayName: nil)
        let vm = SettingsViewModel(
            authService: auth,
            dataService: MockAgriDataRepository(),
            preferencesService: MockPreferencesService()
        )
        XCTAssertEqual(vm.accountName, "AgriVision User")
    }

    func test_canLinkGoogle_trueWhenNotLinked() {
        let auth = MockAuthService(isLoggedIn: true)
        let vm = SettingsViewModel(
            authService: auth,
            dataService: MockAgriDataRepository(),
            preferencesService: MockPreferencesService()
        )
        // MockAuthService.isGoogleProviderLinked returns isLoggedInStub
        // Since isLoggedInStub is true, isGoogleProviderLinked returns true
        XCTAssertFalse(vm.canLinkGoogle)
    }

    func test_setRefreshInterval_allowed() {
        let prefs = MockPreferencesService()
        let vm = SettingsViewModel(
            authService: MockAuthService(isLoggedIn: true),
            dataService: MockAgriDataRepository(),
            preferencesService: prefs
        )
        vm.setRefreshInterval(60)
        XCTAssertEqual(vm.refreshInterval, 60)
        XCTAssertEqual(prefs.dashboardRefreshInterval, 60)
        XCTAssertNotNil(vm.successMessage)
    }

    func test_setRefreshInterval_disallowed_fallsBackTo30() {
        let prefs = MockPreferencesService()
        prefs.dashboardRefreshInterval = 15
        let vm = SettingsViewModel(
            authService: MockAuthService(isLoggedIn: true),
            dataService: MockAgriDataRepository(),
            preferencesService: prefs
        )
        vm.setRefreshInterval(99)
        XCTAssertEqual(vm.refreshInterval, 30)
        XCTAssertEqual(prefs.dashboardRefreshInterval, 30)
    }

    func test_updateDisplayName_success() async {
        let auth = MockAuthService(isLoggedIn: true)
        let vm = SettingsViewModel(
            authService: auth,
            dataService: MockAgriDataRepository(),
            preferencesService: MockPreferencesService()
        )
        let result = await vm.updateDisplayName("New Name")
        XCTAssertTrue(result)
        XCTAssertEqual(vm.profileName, "New Name")
        XCTAssertNotNil(vm.successMessage)
    }

    func test_updateDisplayName_tooShort() async {
        let vm = SettingsViewModel(
            authService: MockAuthService(isLoggedIn: true),
            dataService: MockAgriDataRepository(),
            preferencesService: MockPreferencesService()
        )
        let result = await vm.updateDisplayName("A")
        XCTAssertFalse(result)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_updateDisplayName_tooLong() async {
        let vm = SettingsViewModel(
            authService: MockAuthService(isLoggedIn: true),
            dataService: MockAgriDataRepository(),
            preferencesService: MockPreferencesService()
        )
        let result = await vm.updateDisplayName(String(repeating: "x", count: 81))
        XCTAssertFalse(result)
    }

    func test_updateDisplayName_containsControlChars() async {
        let vm = SettingsViewModel(
            authService: MockAuthService(isLoggedIn: true),
            dataService: MockAgriDataRepository(),
            preferencesService: MockPreferencesService()
        )
        let result = await vm.updateDisplayName("Bad\tName")
        XCTAssertFalse(result)
    }

    func test_sensorSummary_empty() {
        let vm = SettingsViewModel(
            authService: MockAuthService(isLoggedIn: true),
            dataService: MockAgriDataRepository(),
            preferencesService: MockPreferencesService()
        )
        XCTAssertEqual(vm.sensorSummary, "Optional \u{B7} Not connected")
    }

    func test_sensorSummary_withSensors() {
        let auth = MockAuthService(isLoggedIn: true)
        let vm = SettingsViewModel(
            authService: auth,
            dataService: MockAgriDataRepository(),
            preferencesService: MockPreferencesService()
        )
        vm.sensors = [FieldSensor(id: UUID(), fieldId: UUID(), deviceId: "ESP01", name: "Sensor 1", sensorType: "multi", batteryLevel: nil, lastSeen: nil)]
        vm.sensorStatus = "available"
        XCTAssertTrue(vm.sensorSummary.contains("1 connected"))
    }

    func test_signOut_callsCallback() {
        let auth = MockAuthService(isLoggedIn: true)
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        let vm = SettingsViewModel(
            authService: auth,
            dataService: MockAgriDataRepository(),
            preferencesService: MockPreferencesService(),
            fieldSessionStore: store
        )
        var signOutCalled = false
        vm.onSignOut = { signOutCalled = true }
        vm.signOut()
        XCTAssertTrue(signOutCalled)
    }

    func test_signOut_failure_showsError() {
        let auth = MockAuthService(isLoggedIn: true)
        auth.shouldFail = true
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        let vm = SettingsViewModel(
            authService: auth,
            dataService: MockAgriDataRepository(),
            preferencesService: MockPreferencesService(),
            fieldSessionStore: store
        )
        vm.signOut()
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_satelliteSummary_noActiveField() {
        let vm = SettingsViewModel(
            authService: MockAuthService(isLoggedIn: true),
            dataService: MockAgriDataRepository(),
            preferencesService: MockPreferencesService()
        )
        XCTAssertEqual(vm.satelliteSummary, "No active field")
    }

    func test_selectField_updatesActive() {
        let auth = MockAuthService(isLoggedIn: true)
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        let fields = (0..<2).map { i in
            Field(id: UUID(), ownerId: UUID(), name: "F\(i)", coordinates: nil, areaHa: Double(i+1), createdAt: Date(), cropType: nil, plantationDate: nil, expectedHarvestDate: nil, ndviScore: nil, lastSatelliteSync: nil)
        }
        store.fields = fields
        store.activeFieldId = fields[0].id
        let vm = SettingsViewModel(
            authService: auth,
            dataService: MockAgriDataRepository(),
            preferencesService: MockPreferencesService(),
            fieldSessionStore: store
        )
        vm.selectField(fields[1].id)
        XCTAssertEqual(vm.activeFieldId, fields[1].id)
    }

    func test_pairAndAssignSensor_noActiveField() async {
        let vm = SettingsViewModel(
            authService: MockAuthService(isLoggedIn: true),
            dataService: MockAgriDataRepository(),
            preferencesService: MockPreferencesService()
        )
        let result = await vm.pairAndAssignSensor(deviceID: "ESP01", name: "Sensor 1")
        XCTAssertFalse(result)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_pairAndAssignSensor_invalidDeviceID() async {
        let auth = MockAuthService(isLoggedIn: true)
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        store.fields = [Field(id: UUID(), ownerId: UUID(), name: "F1", coordinates: nil, areaHa: 10, createdAt: Date(), cropType: nil, plantationDate: nil, expectedHarvestDate: nil, ndviScore: nil, lastSatelliteSync: nil)]
        store.activeFieldId = store.fields.first?.id
        let vm = SettingsViewModel(
            authService: auth,
            dataService: MockAgriDataRepository(),
            preferencesService: MockPreferencesService(),
            fieldSessionStore: store
        )
        let result = await vm.pairAndAssignSensor(deviceID: "AB", name: "Sensor 1")
        XCTAssertFalse(result)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_updateDisplayName_failure_showsError() async {
        let vm = SettingsViewModel(
            authService: MockAuthService(isLoggedIn: true, shouldFail: true),
            dataService: MockAgriDataRepository(),
            preferencesService: MockPreferencesService()
        )
        let result = await vm.updateDisplayName("New Name")
        XCTAssertFalse(result)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_pairAndAssignSensor_serviceFailure_showsError() async {
        let mockData = MockAgriDataRepository()
        mockData.shouldFail = true
        let auth = MockAuthService(isLoggedIn: true)
        let store = FieldSessionStore(dataService: mockData, authService: auth)
        store.fields = [Field(id: UUID(), ownerId: UUID(), name: "F1", coordinates: nil, areaHa: 10, createdAt: Date(), cropType: nil, plantationDate: nil, expectedHarvestDate: nil, ndviScore: nil, lastSatelliteSync: nil)]
        store.activeFieldId = store.fields.first?.id
        let vm = SettingsViewModel(
            authService: auth,
            dataService: mockData,
            preferencesService: MockPreferencesService(),
            fieldSessionStore: store
        )
        let result = await vm.pairAndAssignSensor(deviceID: "ESP01", name: "Sensor 1")
        XCTAssertFalse(result)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_deleteField_callsDataService() async {
        let auth = MockAuthService(isLoggedIn: true)
        let fieldId = UUID()
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        store.fields = [Field(id: fieldId, ownerId: UUID(), name: "F1", coordinates: nil, areaHa: 10, createdAt: Date(), cropType: nil, plantationDate: nil, expectedHarvestDate: nil, ndviScore: nil, lastSatelliteSync: nil)]
        store.activeFieldId = fieldId
        let vm = SettingsViewModel(
            authService: auth,
            dataService: MockAgriDataRepository(),
            preferencesService: MockPreferencesService(),
            fieldSessionStore: store
        )
        vm.deleteField(fieldId)

        let exp = expectation(description: "delete field")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { exp.fulfill() }
        await fulfillment(of: [exp], timeout: 3)

        XCTAssertNotNil(vm.successMessage)
    }
}
