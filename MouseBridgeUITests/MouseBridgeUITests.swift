import XCTest

final class MouseBridgeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchDoesNotCrash() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 2) || app.wait(for: .runningBackground, timeout: 2))
        app.terminate()
    }
}
