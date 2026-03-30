import XCTest

final class PomodoroFocusUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        // 验证 App 正常启动，主界面可见
        XCTAssertTrue(app.staticTexts["PomodoroFocus"].waitForExistence(timeout: 5))
    }

    func testMainPlaceholderViewVisible() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        // 验证占位主界面包含预期文本
        XCTAssertTrue(app.staticTexts["专注番茄工作法"].waitForExistence(timeout: 5))
    }
}
