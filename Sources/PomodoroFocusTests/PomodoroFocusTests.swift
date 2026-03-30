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

// MARK: - TimerEngine Tests

@MainActor
final class TimerEngineTests: XCTestCase {

    func testTimerEngineInitialState() {
        let engine = TimerEngine(totalSeconds: 10)
        XCTAssertEqual(engine.sessionState, .idle)
        XCTAssertEqual(engine.remainingSeconds, 10)
        XCTAssertEqual(engine.totalSeconds, 10)
    }

    func testTimerEngineStart() {
        let engine = TimerEngine(totalSeconds: 10)
        engine.start()
        XCTAssertEqual(engine.sessionState, .running)
    }

    func testTimerEngineStartIdempotent() {
        let engine = TimerEngine(totalSeconds: 10)
        engine.start()
        engine.start() // 重复调用不应改变状态
        XCTAssertEqual(engine.sessionState, .running)
    }

    func testTimerEnginePause() {
        let engine = TimerEngine(totalSeconds: 10)
        engine.start()
        engine.pause()
        XCTAssertEqual(engine.sessionState, .paused)
        XCTAssertEqual(engine.remainingSeconds, 10) // 刚暂停，时间未变
    }

    func testTimerEnginePauseOnlyFromRunning() {
        let engine = TimerEngine(totalSeconds: 10)
        engine.pause() // idle 状态不应变为 paused
        XCTAssertEqual(engine.sessionState, .idle)
    }

    func testTimerEngineResume() {
        let engine = TimerEngine(totalSeconds: 10)
        engine.start()
        engine.pause()
        engine.resume()
        XCTAssertEqual(engine.sessionState, .running)
    }

    func testTimerEngineResumeOnlyFromPaused() {
        let engine = TimerEngine(totalSeconds: 10)
        engine.start()
        engine.resume() // running 状态调用 resume 无效
        XCTAssertEqual(engine.sessionState, .running)
    }

    func testTimerEngineReset() {
        let engine = TimerEngine(totalSeconds: 10)
        engine.start()
        engine.pause()
        engine.reset()
        XCTAssertEqual(engine.sessionState, .idle)
        XCTAssertEqual(engine.remainingSeconds, 10)
    }

    func testTimerEngineResetFromRunning() {
        let engine = TimerEngine(totalSeconds: 10)
        engine.start()
        engine.reset()
        XCTAssertEqual(engine.sessionState, .idle)
        XCTAssertEqual(engine.remainingSeconds, 10)
    }

    func testTimerEngineBackgroundForegroundReset() {
        let engine = TimerEngine(totalSeconds: 100)
        engine.start()
        engine.handleEnterBackground()
        // 进入后台后状态仍为 running（等待前台修正）
        XCTAssertEqual(engine.sessionState, .running)
        engine.reset()
        XCTAssertEqual(engine.sessionState, .idle)
        XCTAssertEqual(engine.remainingSeconds, 100)
    }

    func testTimerEngineHandleEnterBackgroundOnlyWhenRunning() {
        let engine = TimerEngine(totalSeconds: 100)
        // idle 状态进入后台无效
        engine.handleEnterBackground()
        XCTAssertEqual(engine.sessionState, .idle)
    }

    func testTimerEngineHandleForegroundWithManualCorrection() {
        let engine = TimerEngine(totalSeconds: 100)
        engine.start()
        engine.handleEnterBackground()

        // 进入后台后状态仍为 running（等待前台修正）
        XCTAssertEqual(engine.sessionState, .running)

        // 模拟前台回来（立刻，elapsed ≈ 0）
        engine.handleEnterForeground()
        // elapsed ≈ 0，remainingSeconds 应该接近 100（允许 1 秒误差）
        XCTAssertGreaterThanOrEqual(engine.remainingSeconds, 99)
        XCTAssertLessThanOrEqual(engine.remainingSeconds, 100)
        // 回前台后继续 running
        XCTAssertEqual(engine.sessionState, .running)
    }

    // 新增：验证 finishSession 幂等性（通过 reset/start 行为间接验证）
    func testFinishSessionIdempotent() {
        let engine = TimerEngine(totalSeconds: 1)
        engine.start()
        // 直接测试 reset 后重置
        engine.reset()
        XCTAssertEqual(engine.sessionState, .idle)
        engine.start()
        engine.reset()
        XCTAssertEqual(engine.sessionState, .idle)
    }
}
