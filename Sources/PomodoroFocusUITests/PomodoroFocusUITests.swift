import XCTest

final class PomodoroFocusUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        // 验证 App 正常启动，计时器标签可见（timerLabel accessibilityIdentifier）
        XCTAssertTrue(app.staticTexts["timerLabel"].waitForExistence(timeout: 5))
    }

    func testTimerShowsInitialTime() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        // 计时器标签存在（内容为 25:00 格式，通过 identifier 验证存在）
        let timerLabel = app.staticTexts["timerLabel"]
        XCTAssertTrue(timerLabel.waitForExistence(timeout: 5))
        // accessibilityLabel 格式为「剩余时间：MM:SS」，验证初始显示 25:00
        XCTAssertTrue(timerLabel.label.contains("25:00"))
    }

    func testTagPickerVisible() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        // 先等待主界面加载完成
        XCTAssertTrue(app.staticTexts["timerLabel"].waitForExistence(timeout: 5))

        // 验证「无标签」按钮可见（tagPickerScrollView 内的元素）
        XCTAssertTrue(app.buttons["无标签"].waitForExistence(timeout: 5))
    }
}
