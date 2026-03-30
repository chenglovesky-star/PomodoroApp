import XCTest
import SwiftData
@testable import PomodoroFocus

final class PomodoroFocusTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let schema = Schema([FocusSession.self, Tag.self, DailyRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    override func tearDownWithError() throws {
        container = nil
    }

    func testModelContainerInitializesWithSchema() throws {
        XCTAssertNotNil(container)
    }

    func testFocusSessionDefaultValues() throws {
        let session = FocusSession()
        XCTAssertEqual(session.duration, 1500)
        XCTAssertFalse(session.isCompleted)
    }

    func testTagDefaultValues() throws {
        let tag = Tag(name: "工作", colorHex: "#FF6B6B")
        XCTAssertEqual(tag.name, "工作")
        XCTAssertEqual(tag.colorHex, "#FF6B6B")
    }

    func testDailyRecordDefaultValues() throws {
        let record = DailyRecord()
        XCTAssertEqual(record.totalFocusSeconds, 0)
        XCTAssertEqual(record.sessionsCount, 0)
    }
}
