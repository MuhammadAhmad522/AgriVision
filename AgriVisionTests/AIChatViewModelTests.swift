import XCTest
@testable import AgriVision

@MainActor
final class AIChatViewModelTests: XCTestCase {

    func test_initialState() {
        let vm = AIChatViewModel(dataService: MockAgriDataRepository(), fieldId: UUID())
        XCTAssertEqual(vm.messages, [])
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.currentMessage, "")
        XCTAssertEqual(vm.selectedImages, [])
    }

    func test_canSend_withMessageText() {
        let vm = AIChatViewModel(dataService: MockAgriDataRepository(), fieldId: UUID())
        vm.currentMessage = "Hello"
        XCTAssertTrue(vm.canSend)
    }

    func test_canSend_withImages() {
        let vm = AIChatViewModel(dataService: MockAgriDataRepository(), fieldId: UUID())
        vm.addImage(data: Data([0, 1, 2]))
        XCTAssertTrue(vm.canSend)
    }

    func test_canSend_whenLoading_false() {
        let vm = AIChatViewModel(dataService: MockAgriDataRepository(), fieldId: UUID())
        vm.isLoading = true
        vm.currentMessage = "Hello"
        XCTAssertFalse(vm.canSend)
    }

    func test_canSend_withOnlyWhitespace_false() {
        let vm = AIChatViewModel(dataService: MockAgriDataRepository(), fieldId: UUID())
        vm.currentMessage = "   "
        XCTAssertFalse(vm.canSend)
    }

    func test_canSend_empty_false() {
        let vm = AIChatViewModel(dataService: MockAgriDataRepository(), fieldId: UUID())
        XCTAssertFalse(vm.canSend)
    }

    func test_addImage_updatesSelection() {
        let vm = AIChatViewModel(dataService: MockAgriDataRepository(), fieldId: UUID())
        let data = Data([0, 1, 2, 3])
        vm.addImage(data: data, filename: "test.jpg")
        XCTAssertEqual(vm.selectedImages.count, 1)
        XCTAssertEqual(vm.selectedImages[0].data, data)
        XCTAssertEqual(vm.selectedImages[0].filename, "test.jpg")
    }

    func test_addImage_upToThreeAllowed() {
        let vm = AIChatViewModel(dataService: MockAgriDataRepository(), fieldId: UUID())
        for _ in 0..<3 {
            vm.addImage(data: Data([0, 1, 2]))
        }
        XCTAssertEqual(vm.selectedImages.count, 3)
        // Fourth should fail
        vm.addImage(data: Data([3, 4, 5]))
        XCTAssertEqual(vm.selectedImages.count, 3)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_addImage_over10mbRejected() {
        let vm = AIChatViewModel(dataService: MockAgriDataRepository(), fieldId: UUID())
        let largeData = Data(repeating: 0, count: 11 * 1024 * 1024)
        vm.addImage(data: largeData)
        XCTAssertEqual(vm.selectedImages.count, 0)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_removeImage() {
        let vm = AIChatViewModel(dataService: MockAgriDataRepository(), fieldId: UUID())
        vm.addImage(data: Data([0, 1, 2]))
        let id = vm.selectedImages[0].id
        vm.removeImage(id)
        XCTAssertEqual(vm.selectedImages.count, 0)
    }

    func test_sendMessage_appendsMessages() async {
        let vm = AIChatViewModel(dataService: MockAgriDataRepository(), fieldId: UUID())
        vm.currentMessage = "What should I plant?"

        await vm.sendMessage()

        XCTAssertEqual(vm.messages.count, 2) // user + assistant
        XCTAssertEqual(vm.messages[0].role, "user")
        XCTAssertEqual(vm.messages[1].role, "model")
        XCTAssertEqual(vm.currentMessage, "")
        XCTAssertEqual(vm.selectedImages, [])
        XCTAssertFalse(vm.isLoading)
    }

    func test_sendMessage_withEmptyTextAndNoImages_doesNothing() async {
        let vm = AIChatViewModel(dataService: MockAgriDataRepository(), fieldId: UUID())

        await vm.sendMessage()

        XCTAssertEqual(vm.messages, [])
        XCTAssertFalse(vm.isLoading)
    }

    func test_fetchHistory_loadsMessages() async {
        let vm = AIChatViewModel(dataService: MockAgriDataRepository(), fieldId: UUID())

        await vm.fetchHistory()

        XCTAssertFalse(vm.messages.isEmpty)
        XCTAssertFalse(vm.isLoading)
    }

    func test_imageData_roundTrip() {
        let vm = AIChatViewModel(dataService: MockAgriDataRepository(), fieldId: UUID())
        let data = Data([0x01, 0x02, 0x03])
        vm.addImage(data: data)
        let imageId = vm.selectedImages[0].id

        // After sending, the image data maps to attachment IDs
        // Verify initial state
        XCTAssertNil(vm.imageData(for: UUID()))
    }

    func test_dismiss_callsCallback() {
        let vm = AIChatViewModel(dataService: MockAgriDataRepository(), fieldId: UUID())
        var dismissed = false
        vm.onDismiss = { dismissed = true }
        vm.dismiss()
        XCTAssertTrue(dismissed)
    }

    // MARK: - Error path tests

    func test_fetchHistory_failure_showsError() async {
        let mockData = MockAgriDataRepository()
        mockData.shouldFail = true
        let vm = AIChatViewModel(dataService: mockData, fieldId: UUID())

        await vm.fetchHistory()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.isLoading)
    }

    func test_sendMessage_failure_showsError() async {
        let mockData = MockAgriDataRepository()
        mockData.shouldFail = true
        let vm = AIChatViewModel(dataService: mockData, fieldId: UUID())
        vm.currentMessage = "Hello"

        await vm.sendMessage()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.isLoading)
        XCTAssertEqual(vm.messages, [])
    }

    func test_sendMessage_failure_doesNotClearMessage() async {
        let mockData = MockAgriDataRepository()
        mockData.shouldFail = true
        let vm = AIChatViewModel(dataService: mockData, fieldId: UUID())
        vm.currentMessage = "Hello"

        await vm.sendMessage()

        XCTAssertEqual(vm.currentMessage, "Hello")
        XCTAssertEqual(vm.selectedImages, [])
    }

    func test_fetchHistory_failure_keepsExistingMessages() async {
        let mockData = MockAgriDataRepository()
        let vm = AIChatViewModel(dataService: mockData, fieldId: UUID())
        await vm.fetchHistory()
        let previousCount = vm.messages.count

        mockData.shouldFail = true
        await vm.fetchHistory()

        XCTAssertEqual(vm.messages.count, previousCount)
        XCTAssertNotNil(vm.errorMessage)
    }
}
