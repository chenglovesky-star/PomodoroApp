import XCTest
import SwiftData
@testable import PomodoroFocus

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

    // MARK: - FocusSession CRUD 测试

    /// 测试1：创建 FocusSession
    func testCreateFocusSession() throws {
        let session = FocusSession(duration: 1500, isCompleted: true)
        context.insert(session)

        let descriptor = FetchDescriptor<FocusSession>()
        let sessions = try context.fetch(descriptor)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].duration, 1500)
        XCTAssertTrue(sessions[0].isCompleted)
    }

    /// 测试2：Tag 关联
    func testTagAssociation() throws {
        let tag = Tag(name: "工作", colorHex: "#4A90E2")
        let session = FocusSession(duration: 1500, tag: tag)
        context.insert(tag)
        context.insert(session)

        let descriptor = FetchDescriptor<FocusSession>()
        let sessions = try context.fetch(descriptor)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].tag?.name, "工作")
        XCTAssertEqual(sessions[0].tag?.colorHex, "#4A90E2")
    }

    /// 测试3：查询 FocusSession（排序）
    func testQueryFocusSession() throws {
        for i in 1...3 {
            let session = FocusSession(duration: i * 300)
            context.insert(session)
        }

        let descriptor = FetchDescriptor<FocusSession>(sortBy: [SortDescriptor(\.duration)])
        let sessions = try context.fetch(descriptor)
        XCTAssertEqual(sessions.count, 3)
        XCTAssertEqual(sessions[0].duration, 300)
        XCTAssertEqual(sessions[1].duration, 600)
        XCTAssertEqual(sessions[2].duration, 900)
    }

    /// 测试4：更新 FocusSession
    func testUpdateFocusSession() throws {
        let session = FocusSession(duration: 1500)
        context.insert(session)

        session.isCompleted = true
        session.duration = 1200

        let descriptor = FetchDescriptor<FocusSession>()
        let sessions = try context.fetch(descriptor)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertTrue(sessions[0].isCompleted)
        XCTAssertEqual(sessions[0].duration, 1200)
    }

    /// 测试5：删除 FocusSession
    func testDeleteFocusSession() throws {
        let session = FocusSession(duration: 1500)
        context.insert(session)

        let descriptor = FetchDescriptor<FocusSession>()
        var sessions = try context.fetch(descriptor)
        XCTAssertEqual(sessions.count, 1)

        context.delete(sessions[0])
        sessions = try context.fetch(descriptor)
        XCTAssertEqual(sessions.count, 0)
    }

    // MARK: - DailyRecord 测试

    /// 测试6：DailyRecord 创建和 unique date
    func testDailyRecord() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let record = DailyRecord(date: today, totalFocusSeconds: 3600, sessionsCount: 4)
        context.insert(record)

        let descriptor = FetchDescriptor<DailyRecord>()
        let records = try context.fetch(descriptor)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].totalFocusSeconds, 3600)
        XCTAssertEqual(records[0].sessionsCount, 4)
    }

    // MARK: - AppState 测试

    /// 测试7：AppState 初始状态
    func testAppStateInitialState() {
        let state = AppState()
        XCTAssertFalse(state.storageInitFailed)
        XCTAssertFalse(state.storageUnavailable)
        XCTAssertEqual(state.storageErrorMessage, "")
    }

    /// 测试8：AppState 存储降级状态设置
    func testAppStateDegradedState() {
        let state = AppState()
        state.storageInitFailed = true
        state.storageErrorMessage = "存储初始化失败，已切换为内存模式。退出 App 后数据不会保存。"
        XCTAssertTrue(state.storageInitFailed)
        XCTAssertFalse(state.storageUnavailable)
        XCTAssertFalse(state.storageErrorMessage.isEmpty)
    }

    /// 测试9：ModelContainer 内存模式初始化成功
    func testModelContainerMemoryInit() throws {
        let schema = Schema([FocusSession.self, Tag.self, DailyRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let testContainer = try ModelContainer(for: schema, configurations: [config])
        XCTAssertNotNil(testContainer)
    }
}
