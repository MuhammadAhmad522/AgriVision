import XCTest
import CoreLocation
@testable import AgriVision

@MainActor
final class DashboardViewModelTests: XCTestCase {

    func test_initialState() {
        let auth = MockAuthService(isLoggedIn: true)
        let vm = DashboardViewModel(
            dataService: MockAgriDataRepository(),
            authService: auth,
            preferencesService: MockPreferencesService(),
            fieldSessionStore: FieldSessionStore(
                dataService: MockAgriDataRepository(),
                authService: auth
            )
        )
        XCTAssertEqual(vm.recommendations, [])
        XCTAssertEqual(vm.advisorStatus, "pending")
        XCTAssertNil(vm.loadedFieldId)
        XCTAssertFalse(vm.isLoading)
    }

    func test_profileInitial_fromDisplayName() {
        let auth = MockAuthService(isLoggedIn: true)
        let vm = DashboardViewModel(
            dataService: MockAgriDataRepository(),
            authService: auth,
            preferencesService: MockPreferencesService(),
            fieldSessionStore: FieldSessionStore(
                dataService: MockAgriDataRepository(),
                authService: auth
            )
        )
        XCTAssertEqual(vm.profileInitial, "U")
    }

    func test_healthSummary_nilWhenNoNDVI() {
        let auth = MockAuthService(isLoggedIn: true)
        let mockData = MockAgriDataRepository()
        let vm = DashboardViewModel(
            dataService: mockData,
            authService: auth,
            preferencesService: MockPreferencesService(),
            fieldSessionStore: FieldSessionStore(
                dataService: MockAgriDataRepository(),
                authService: auth
            )
        )
        XCTAssertNil(vm.healthSummary)
    }

    func test_healthSummary_excellent() {
        let field = Field(
            id: UUID(), ownerId: UUID(), name: "Test",
            coordinates: nil, areaHa: 10, createdAt: Date(),
            cropType: "Wheat", plantationDate: nil, expectedHarvestDate: nil,
            ndviScore: 0.85, lastSatelliteSync: nil
        )
        let auth = MockAuthService(isLoggedIn: true)
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        store.fields = [field]
        store.activeFieldId = field.id
        let vm = DashboardViewModel(
            dataService: MockAgriDataRepository(),
            authService: auth,
            preferencesService: MockPreferencesService(),
            fieldSessionStore: store
        )
        XCTAssertEqual(vm.healthSummary?.score, 0.85)
        XCTAssertEqual(vm.healthSummary?.message, "Excellent Crop Health")
        XCTAssertEqual(vm.healthSummary?.color, "green")
    }

    func test_healthSummary_monitor() {
        let field = Field(
            id: UUID(), ownerId: UUID(), name: "Test",
            coordinates: nil, areaHa: 10, createdAt: Date(),
            cropType: "Wheat", plantationDate: nil, expectedHarvestDate: nil,
            ndviScore: 0.55, lastSatelliteSync: nil
        )
        let auth = MockAuthService(isLoggedIn: true)
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        store.fields = [field]
        store.activeFieldId = field.id
        let vm = DashboardViewModel(
            dataService: MockAgriDataRepository(),
            authService: auth,
            preferencesService: MockPreferencesService(),
            fieldSessionStore: store
        )
        XCTAssertEqual(vm.healthSummary?.message, "Monitor Crop Health")
        XCTAssertEqual(vm.healthSummary?.color, "orange")
    }

    func test_healthSummary_inspect() {
        let field = Field(
            id: UUID(), ownerId: UUID(), name: "Test",
            coordinates: nil, areaHa: 10, createdAt: Date(),
            cropType: "Wheat", plantationDate: nil, expectedHarvestDate: nil,
            ndviScore: 0.2, lastSatelliteSync: nil
        )
        let auth = MockAuthService(isLoggedIn: true)
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        store.fields = [field]
        store.activeFieldId = field.id
        let vm = DashboardViewModel(
            dataService: MockAgriDataRepository(),
            authService: auth,
            preferencesService: MockPreferencesService(),
            fieldSessionStore: store
        )
        XCTAssertEqual(vm.healthSummary?.message, "Inspection Recommended")
        XCTAssertEqual(vm.healthSummary?.color, "red")
    }

    func test_signOut_clearsStore() {
        let auth = MockAuthService(isLoggedIn: true)
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        store.fields = [Field(id: UUID(), ownerId: UUID(), name: "F", coordinates: nil, areaHa: 1, createdAt: Date(), cropType: nil, plantationDate: nil, expectedHarvestDate: nil, ndviScore: nil, lastSatelliteSync: nil)]
        store.activeFieldId = UUID()
        let vm = DashboardViewModel(
            dataService: MockAgriDataRepository(),
            authService: auth,
            preferencesService: MockPreferencesService(),
            fieldSessionStore: store
        )
        var signOutCalled = false
        vm.onSignOut = { signOutCalled = true }
        vm.signOut()
        XCTAssertTrue(signOutCalled)
    }

    func test_openChat_callsCallback() {
        let auth = MockAuthService(isLoggedIn: true)
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        let fieldId = UUID()
        store.activeFieldId = fieldId
        let vm = DashboardViewModel(
            dataService: MockAgriDataRepository(),
            authService: auth,
            preferencesService: MockPreferencesService(),
            fieldSessionStore: store
        )
        var chatFieldId: UUID?
        vm.onChatTapped = { chatFieldId = $0 }
        vm.openChat()
        XCTAssertEqual(chatFieldId, fieldId)
    }

    func test_addField_whenNotAtLimit_callsCallback() {
        let auth = MockAuthService(isLoggedIn: true)
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        store.activeFieldLimit = 5
        let vm = DashboardViewModel(
            dataService: MockAgriDataRepository(),
            authService: auth,
            preferencesService: MockPreferencesService(),
            fieldSessionStore: store
        )
        var addCalled = false
        vm.onAddFieldTapped = { addCalled = true }
        vm.addField()
        XCTAssertTrue(addCalled)
    }

    func test_addField_whenAtLimit_showsError() {
        let auth = MockAuthService(isLoggedIn: true)
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        store.fields = (0..<5).map { _ in Field(id: UUID(), ownerId: UUID(), name: "F", coordinates: nil, areaHa: 1, createdAt: Date(), cropType: nil, plantationDate: nil, expectedHarvestDate: nil, ndviScore: nil, lastSatelliteSync: nil) }
        store.activeFieldId = store.fields.first?.id
        store.activeFieldLimit = 5
        let vm = DashboardViewModel(
            dataService: MockAgriDataRepository(),
            authService: auth,
            preferencesService: MockPreferencesService(),
            fieldSessionStore: store
        )
        var addCalled = false
        vm.onAddFieldTapped = { addCalled = true }
        vm.addField()
        XCTAssertFalse(addCalled)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_updateFeedback_updatesRecommendation() async {
        let recId = UUID()
        let fieldId = UUID()
        let auth = MockAuthService(isLoggedIn: true)
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        store.activeFieldId = fieldId
        let vm = DashboardViewModel(
            dataService: MockAgriDataRepository(),
            authService: auth,
            preferencesService: MockPreferencesService(),
            fieldSessionStore: store
        )
        let rec = FieldRecommendation(
            id: recId, fieldId: fieldId, category: "Irrigation", priority: "high",
            advice: "Test", confidence: 0.5, status: "pending", ndviAtGeneration: nil, createdAt: Date()
        )
        vm.recommendations = [rec]

        await vm.updateFeedback(rec, status: "implemented")

        XCTAssertEqual(vm.recommendations.first?.status, "implemented")
    }

    func test_recordOutcome_updatesRecommendation() async {
        let recId = UUID()
        let fieldId = UUID()
        let auth = MockAuthService(isLoggedIn: true)
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        store.activeFieldId = fieldId
        let vm = DashboardViewModel(
            dataService: MockAgriDataRepository(),
            authService: auth,
            preferencesService: MockPreferencesService(),
            fieldSessionStore: store
        )
        let rec = FieldRecommendation(
            id: recId, fieldId: fieldId, category: "Irrigation", priority: "high",
            advice: "Test", confidence: 0.5, status: "implemented", ndviAtGeneration: nil, createdAt: Date()
        )
        vm.recommendations = [rec]

        await vm.recordOutcome(rec, outcome: "useful")

        XCTAssertEqual(vm.recommendations.first?.outcome, "useful")
    }

    // MARK: - Error path tests

    func test_refreshData_failure_showsError() async {
        let mockData = MockAgriDataRepository()
        let auth = MockAuthService(isLoggedIn: true)
        let store = FieldSessionStore(dataService: mockData, authService: auth)
        try? await store.bootstrap()
        mockData.shouldFail = true
        let vm = DashboardViewModel(
            dataService: mockData,
            authService: auth,
            preferencesService: MockPreferencesService(),
            fieldSessionStore: store
        )

        await vm.refreshData()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.isLoading)
    }

    func test_refreshRecommendations_failure_showsError() async {
        let mockData = MockAgriDataRepository()
        let auth = MockAuthService(isLoggedIn: true)
        let store = FieldSessionStore(dataService: mockData, authService: auth)
        try? await store.bootstrap()
        mockData.shouldFail = true
        let vm = DashboardViewModel(
            dataService: mockData,
            authService: auth,
            preferencesService: MockPreferencesService(),
            fieldSessionStore: store
        )

        await vm.refreshRecommendations()

        XCTAssertEqual(vm.advisorStatus, "unavailable")
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.isRefreshingAI)
    }

    func test_updateFeedback_failure_showsError() async {
        let mockData = MockAgriDataRepository()
        mockData.shouldFail = true
        let auth = MockAuthService(isLoggedIn: true)
        let store = FieldSessionStore(dataService: mockData, authService: auth)
        try? await store.bootstrap()
        let vm = DashboardViewModel(
            dataService: mockData,
            authService: auth,
            preferencesService: MockPreferencesService(),
            fieldSessionStore: store
        )
        let rec = FieldRecommendation(
            id: UUID(), fieldId: UUID(), category: "Irrigation", priority: "high",
            advice: "Test", confidence: 0.5, status: "pending", ndviAtGeneration: nil, createdAt: Date()
        )

        await vm.updateFeedback(rec, status: "implemented")

        XCTAssertNotNil(vm.errorMessage)
    }

    func test_recordOutcome_failure_showsError() async {
        let mockData = MockAgriDataRepository()
        mockData.shouldFail = true
        let auth = MockAuthService(isLoggedIn: true)
        let store = FieldSessionStore(dataService: mockData, authService: auth)
        try? await store.bootstrap()
        let vm = DashboardViewModel(
            dataService: mockData,
            authService: auth,
            preferencesService: MockPreferencesService(),
            fieldSessionStore: store
        )
        let rec = FieldRecommendation(
            id: UUID(), fieldId: UUID(), category: "Irrigation", priority: "high",
            advice: "Test", confidence: 0.5, status: "implemented", ndviAtGeneration: nil, createdAt: Date()
        )

        await vm.recordOutcome(rec, outcome: "useful")

        XCTAssertNotNil(vm.errorMessage)
    }

    func test_requestDataRefresh_failure_showsError() async {
        let mockData = MockAgriDataRepository()
        let auth = MockAuthService(isLoggedIn: true)
        let store = FieldSessionStore(dataService: mockData, authService: auth)
        try? await store.bootstrap()
        mockData.shouldFail = true
        let vm = DashboardViewModel(
            dataService: mockData,
            authService: auth,
            preferencesService: MockPreferencesService(),
            fieldSessionStore: store
        )

        await vm.requestDataRefresh()

        XCTAssertNotNil(vm.errorMessage)
    }
}

final class FieldSessionStoreTests: XCTestCase {

    @MainActor func test_initialState() {
        let auth = MockAuthService()
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        XCTAssertEqual(store.fields, [])
        XCTAssertNil(store.activeFieldId)
        XCTAssertEqual(store.activeFieldLimit, 5)
        XCTAssertFalse(store.isRefreshing)
        XCTAssertNil(store.activeField)
    }

    @MainActor func test_hasReachedLimit() {
        let auth = MockAuthService()
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        store.activeFieldLimit = 2
        XCTAssertFalse(store.hasReachedLimit)
        store.fields = [Field(id: UUID(), ownerId: UUID(), name: "A", coordinates: nil, areaHa: 1, createdAt: Date(), cropType: nil, plantationDate: nil, expectedHarvestDate: nil, ndviScore: nil, lastSatelliteSync: nil)]
        XCTAssertFalse(store.hasReachedLimit)
        store.fields = [
            Field(id: UUID(), ownerId: UUID(), name: "A", coordinates: nil, areaHa: 1, createdAt: Date(), cropType: nil, plantationDate: nil, expectedHarvestDate: nil, ndviScore: nil, lastSatelliteSync: nil),
            Field(id: UUID(), ownerId: UUID(), name: "B", coordinates: nil, areaHa: 1, createdAt: Date(), cropType: nil, plantationDate: nil, expectedHarvestDate: nil, ndviScore: nil, lastSatelliteSync: nil),
        ]
        XCTAssertTrue(store.hasReachedLimit)
    }

    @MainActor func test_select_validID() {
        let auth = MockAuthService()
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        let field = Field(id: UUID(), ownerId: UUID(), name: "Test", coordinates: nil, areaHa: 10, createdAt: Date(), cropType: nil, plantationDate: nil, expectedHarvestDate: nil, ndviScore: nil, lastSatelliteSync: nil)
        store.fields = [field]

        store.select(field.id)

        XCTAssertEqual(store.activeFieldId, field.id)
        XCTAssertEqual(store.activeField?.id, field.id)
    }

    @MainActor func test_select_invalidID_ignored() {
        let auth = MockAuthService()
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        store.fields = [Field(id: UUID(), ownerId: UUID(), name: "Test", coordinates: nil, areaHa: 10, createdAt: Date(), cropType: nil, plantationDate: nil, expectedHarvestDate: nil, ndviScore: nil, lastSatelliteSync: nil)]
        let unknownID = UUID()

        store.select(unknownID)

        XCTAssertNil(store.activeFieldId)
    }

    @MainActor func test_selectPrevious() {
        let auth = MockAuthService()
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        let fields = (0..<3).map { i in Field(id: UUID(), ownerId: UUID(), name: "F\(i)", coordinates: nil, areaHa: Double(i+1), createdAt: Date(), cropType: nil, plantationDate: nil, expectedHarvestDate: nil, ndviScore: nil, lastSatelliteSync: nil) }
        store.fields = fields
        store.activeFieldId = fields[1].id

        store.selectPrevious()

        XCTAssertEqual(store.activeFieldId, fields[0].id)
    }

    @MainActor func test_selectNext() {
        let auth = MockAuthService()
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        let fields = (0..<3).map { i in Field(id: UUID(), ownerId: UUID(), name: "F\(i)", coordinates: nil, areaHa: Double(i+1), createdAt: Date(), cropType: nil, plantationDate: nil, expectedHarvestDate: nil, ndviScore: nil, lastSatelliteSync: nil) }
        store.fields = fields
        store.activeFieldId = fields[1].id

        store.selectNext()

        XCTAssertEqual(store.activeFieldId, fields[2].id)
    }

    @MainActor func test_selectPrevious_atFirst_doesNothing() {
        let auth = MockAuthService()
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        let fields = (0..<2).map { i in Field(id: UUID(), ownerId: UUID(), name: "F\(i)", coordinates: nil, areaHa: Double(i+1), createdAt: Date(), cropType: nil, plantationDate: nil, expectedHarvestDate: nil, ndviScore: nil, lastSatelliteSync: nil) }
        store.fields = fields
        store.activeFieldId = fields[0].id

        store.selectPrevious()

        XCTAssertEqual(store.activeFieldId, fields[0].id)
    }

    @MainActor func test_merge_updatesExistingField() {
        let auth = MockAuthService()
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        let field = Field(id: UUID(), ownerId: UUID(), name: "Original", coordinates: nil, areaHa: 10, createdAt: Date(), cropType: nil, plantationDate: nil, expectedHarvestDate: nil, ndviScore: nil, lastSatelliteSync: nil)
        store.fields = [field]

        let updated = Field(id: field.id, ownerId: UUID(), name: "Updated", coordinates: nil, areaHa: 20, createdAt: Date(), cropType: nil, plantationDate: nil, expectedHarvestDate: nil, ndviScore: nil, lastSatelliteSync: nil)
        store.merge(updated)

        XCTAssertEqual(store.fields.first?.name, "Updated")
        XCTAssertEqual(store.fields.first?.areaHa, 20)
    }

    @MainActor func test_merge_unknownField_ignored() {
        let auth = MockAuthService()
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        store.fields = [Field(id: UUID(), ownerId: UUID(), name: "A", coordinates: nil, areaHa: 10, createdAt: Date(), cropType: nil, plantationDate: nil, expectedHarvestDate: nil, ndviScore: nil, lastSatelliteSync: nil)]

        let unknown = Field(id: UUID(), ownerId: UUID(), name: "B", coordinates: nil, areaHa: 5, createdAt: Date(), cropType: nil, plantationDate: nil, expectedHarvestDate: nil, ndviScore: nil, lastSatelliteSync: nil)
        store.merge(unknown)

        XCTAssertEqual(store.fields.count, 1)
    }

    @MainActor func test_merge_archivedField_ignored() {
        let auth = MockAuthService()
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        let field = Field(id: UUID(), ownerId: UUID(), name: "A", coordinates: nil, areaHa: 10, createdAt: Date(), cropType: nil, plantationDate: nil, expectedHarvestDate: nil, ndviScore: nil, lastSatelliteSync: nil)
        store.fields = [field]

        let archived = Field(id: field.id, ownerId: UUID(), name: "Archived", coordinates: nil, areaHa: 10, createdAt: Date(), cropType: nil, plantationDate: nil, expectedHarvestDate: nil, status: "archived", ndviScore: nil, lastSatelliteSync: nil)
        store.merge(archived)

        XCTAssertEqual(store.fields.first?.name, "A")
    }

    @MainActor func test_clear() {
        let auth = MockAuthService()
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        store.fields = [Field(id: UUID(), ownerId: UUID(), name: "A", coordinates: nil, areaHa: 1, createdAt: Date(), cropType: nil, plantationDate: nil, expectedHarvestDate: nil, ndviScore: nil, lastSatelliteSync: nil)]
        store.activeFieldId = UUID()

        store.clear()

        XCTAssertEqual(store.fields, [])
        XCTAssertNil(store.activeFieldId)
    }

    @MainActor func test_refresh_failure_setsLastError() async throws {
        let mockData = MockAgriDataRepository()
        let auth = MockAuthService()
        let store = FieldSessionStore(dataService: mockData, authService: auth)
        try await store.bootstrap()

        mockData.shouldFail = true
        do {
            try await store.refresh()
            XCTFail("Expected error")
        } catch {
            XCTAssertNotNil(store.lastError)
        }
    }

    @MainActor func test_deleteActiveField_failure_keepsField() async throws {
        let mockData = MockAgriDataRepository()
        let auth = MockAuthService()
        let store = FieldSessionStore(dataService: mockData, authService: auth)
        try await store.bootstrap()
        let previousCount = store.fields.count

        mockData.shouldFail = true
        do {
            try await store.deleteActiveField()
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(store.fields.count, previousCount)
            XCTAssertNotNil(store.activeFieldId)
        }
    }

    @MainActor func test_bootstrap_failure_clearsFields() async throws {
        let mockData = MockAgriDataRepository()
        mockData.shouldFail = true
        let auth = MockAuthService()
        let store = FieldSessionStore(dataService: mockData, authService: auth)

        do {
            try await store.bootstrap()
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(store.fields, [])
            XCTAssertNil(store.activeFieldId)
        }
    }

    @MainActor func test_bootstrap_success() async throws {
        let auth = MockAuthService()
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)

        try await store.bootstrap()

        XCTAssertFalse(store.fields.isEmpty)
        XCTAssertNotNil(store.activeFieldId)
        XCTAssertEqual(store.activeFieldLimit, 5)
    }

    @MainActor func test_currentCropType_returnsType() {
        let auth = MockAuthService(isLoggedIn: true)
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        let fieldId = UUID()
        let field = Field(
            id: fieldId, ownerId: UUID(), name: "Test",
            coordinates: nil, areaHa: 10, createdAt: Date(),
            cropType: "Rice", plantationDate: nil, expectedHarvestDate: nil,
            ndviScore: nil, lastSatelliteSync: nil
        )
        store.fields = [field]
        store.activeFieldId = fieldId

        let vm = DashboardViewModel(
            dataService: MockAgriDataRepository(),
            authService: auth,
            preferencesService: MockPreferencesService(),
            fieldSessionStore: store
        )
        XCTAssertEqual(vm.currentCropType, "Rice")
    }

    @MainActor func test_currentCropType_unknown() {
        let auth = MockAuthService(isLoggedIn: true)
        let store = FieldSessionStore(dataService: MockAgriDataRepository(), authService: auth)
        let fieldId = UUID()
        let field = Field(id: fieldId, ownerId: UUID(), name: "Test", coordinates: nil, areaHa: 10, createdAt: Date(), cropType: nil, plantationDate: nil, expectedHarvestDate: nil, ndviScore: nil, lastSatelliteSync: nil)
        store.fields = [field]
        store.activeFieldId = fieldId

        let vm = DashboardViewModel(
            dataService: MockAgriDataRepository(),
            authService: auth,
            preferencesService: MockPreferencesService(),
            fieldSessionStore: store
        )
        XCTAssertEqual(vm.currentCropType, "Unknown crop")
    }
}
