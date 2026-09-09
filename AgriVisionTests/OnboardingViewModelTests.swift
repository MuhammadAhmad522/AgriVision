import XCTest
@testable import AgriVision

final class OnboardingViewModelTests: XCTestCase {

    func test_initialState() {
        let vm = OnboardingViewModel()
        XCTAssertEqual(vm.currentPage, 0)
        XCTAssertEqual(vm.pages.count, 3)
        XCTAssertFalse(vm.isProgrammaticChange)
    }

    func test_handleNextAction_advancesPage() {
        let vm = OnboardingViewModel()
        var completed = false

        vm.handleNextAction(onComplete: { completed = true })

        XCTAssertEqual(vm.currentPage, 1)
        XCTAssertTrue(vm.isProgrammaticChange)
        XCTAssertFalse(completed)
    }

    func test_handleNextAction_fromLastPage_completes() {
        let vm = OnboardingViewModel()
        vm.currentPage = 2
        var completed = false

        vm.handleNextAction(onComplete: { completed = true })

        XCTAssertEqual(vm.currentPage, 2)
        XCTAssertTrue(completed)
    }

    func test_handleNextAction_resetsProgrammaticFlag() {
        let vm = OnboardingViewModel()

        vm.handleNextAction(onComplete: {})

        XCTAssertTrue(vm.isProgrammaticChange)

        // After the async delay, it should reset
        let exp = expectation(description: "reset flag")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertFalse(vm.isProgrammaticChange)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2)
    }

    func test_handlePreferenceChange_duringProgrammatic_ignored() {
        let vm = OnboardingViewModel()
        vm.isProgrammaticChange = true

        vm.handlePreferenceChange(dictionary: [0: -100])

        XCTAssertEqual(vm.scrollOffset, 0)
    }

    func test_handlePreferenceChange_updatesOffset() {
        let vm = OnboardingViewModel()
        vm.containerWidth = 390

        vm.handlePreferenceChange(dictionary: [0: -100])

        XCTAssertEqual(vm.scrollOffset, -100)
    }

    func test_handlePreferenceChange_withMultiplePages() {
        let vm = OnboardingViewModel()
        vm.containerWidth = 390
        vm.currentPage = 1

        vm.handlePreferenceChange(dictionary: [0: -390, 1: 0])

        XCTAssertEqual(vm.scrollOffset, -390)
    }

    func test_pageContent() {
        let vm = OnboardingViewModel()
        XCTAssertEqual(vm.pages[0].title, "AgriVision")
        XCTAssertTrue(vm.pages[1].title.contains("Map Your Fields"))
        XCTAssertTrue(vm.pages[2].title.contains("Analyze soil"))
    }
}
