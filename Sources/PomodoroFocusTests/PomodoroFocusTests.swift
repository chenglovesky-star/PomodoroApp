import XCTest
import SwiftData
@testable import PomodoroFocus

// MARK: - SwiftData Unit Tests

@MainActor
final class PomodoroFocusTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([FocusSession.self, Tag.self, DailyRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // MARK: - FocusSession CRUD

    func testCreateFocusSession() throws {
        let session = FocusSession(duration: 1500, isCompleted: true)
        context.insert(session)

        let sessions = try context.fetch(FetchDescriptor<FocusSession>())
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].duration, 1500)
        XCTAssertTrue(sessions[0].isCompleted)
    }

    func testQueryFocusSessionSorted() throws {
        for d in [300, 900, 1500] { context.insert(FocusSession(duration: d)) }
        let descriptor = FetchDescriptor<FocusSession>(sortBy: [SortDescriptor(\.duration)])
        let sessions = try context.fetch(descriptor)
        XCTAssertEqual(sessions.count, 3)
        XCTAssertEqual(sessions[0].duration, 300)
        XCTAssertEqual(sessions[2].duration, 1500)
    }

    func testUpdateFocusSession() throws {
        let session = FocusSession(duration: 1500)
        context.insert(session)
        session.isCompleted = true
        let sessions = try context.fetch(FetchDescriptor<FocusSession>())
        XCTAssertTrue(sessions[0].isCompleted)
    }

    func testDeleteFocusSession() throws {
        let session = FocusSession(duration: 1500)
        context.insert(session)
        var sessions = try context.fetch(FetchDescriptor<FocusSession>())
        XCTAssertEqual(sessions.count, 1)
        context.delete(sessions[0])
        sessions = try context.fetch(FetchDescriptor<FocusSession>())
        XCTAssertEqual(sessions.count, 0)
    }

    // MARK: - Tag 关联

    func testTagAssociation() throws {
        let tag = Tag(name: "工作", colorHex: "#4A90E2")
        let session = FocusSession(duration: 1500, tag: tag)
        context.insert(tag)
        context.insert(session)
        let sessions = try context.fetch(FetchDescriptor<FocusSession>())
        XCTAssertEqual(sessions[0].tag?.name, "工作")
    }

    // MARK: - DailyRecord

    func testDailyRecordUsesStartOfDay() throws {
        let now = Date()
        let record = DailyRecord(date: now, totalFocusSeconds: 3600, sessionsCount: 4)
        context.insert(record)

        let records = try context.fetch(FetchDescriptor<DailyRecord>())
        XCTAssertEqual(records.count, 1)
        // date 应等于今天零点
        let expected = Calendar.current.startOfDay(for: now)
        XCTAssertEqual(records[0].date, expected)
        XCTAssertEqual(records[0].totalFocusSeconds, 3600)
    }

    // MARK: - AppState & Container

    func testAppStateInitialState() {
        let state = AppState()
        XCTAssertFalse(state.storageInitFailed)
        XCTAssertFalse(state.storageUnavailable)
        XCTAssertTrue(state.storageErrorMessage.isEmpty)
    }

    func testModelContainerInMemory() throws {
        let schema = Schema([FocusSession.self, Tag.self, DailyRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let c = try ModelContainer(for: schema, configurations: [config])
        XCTAssertNotNil(c)
    }
}
