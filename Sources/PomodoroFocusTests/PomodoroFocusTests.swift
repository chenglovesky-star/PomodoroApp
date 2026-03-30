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

// MARK: - MockNotificationCenter

final class MockNotificationCenter: NotificationScheduling {
    var addedRequests: [UNNotificationRequest] = []
    var removedPendingIdentifiers: [String] = []
    var removedDeliveredIdentifiers: [String] = []
    var authorizationRequested = false

    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?) {
        addedRequests.append(request)
        completionHandler?(nil)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedPendingIdentifiers.append(contentsOf: identifiers)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        removedDeliveredIdentifiers.append(contentsOf: identifiers)
    }

    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping (Bool, Error?) -> Void) {
        authorizationRequested = true
        completionHandler(true, nil)
    }
}

// MARK: - TimerEngine Tests

@MainActor
final class TimerEngineTests: XCTestCase {

    func testTimerEngineInitialState() {
        let engine = TimerEngine(totalSeconds: 10, notificationCenter: MockNotificationCenter())
        XCTAssertEqual(engine.sessionState, .idle)
        XCTAssertEqual(engine.remainingSeconds, 10)
        XCTAssertEqual(engine.totalSeconds, 10)
    }

    func testTimerEngineStart() {
        let engine = TimerEngine(totalSeconds: 10, notificationCenter: MockNotificationCenter())
        engine.start()
        XCTAssertEqual(engine.sessionState, .running)
    }

    func testTimerEngineStartIdempotent() {
        let engine = TimerEngine(totalSeconds: 10, notificationCenter: MockNotificationCenter())
        engine.start()
        engine.start() // 重复调用不应改变状态
        XCTAssertEqual(engine.sessionState, .running)
    }

    func testTimerEnginePause() {
        let engine = TimerEngine(totalSeconds: 10, notificationCenter: MockNotificationCenter())
        engine.start()
        engine.pause()
        XCTAssertEqual(engine.sessionState, .paused)
        XCTAssertEqual(engine.remainingSeconds, 10) // 刚暂停，时间未变
    }

    func testTimerEnginePauseOnlyFromRunning() {
        let engine = TimerEngine(totalSeconds: 10, notificationCenter: MockNotificationCenter())
        engine.pause() // idle 状态不应变为 paused
        XCTAssertEqual(engine.sessionState, .idle)
    }

    func testTimerEngineResume() {
        let engine = TimerEngine(totalSeconds: 10, notificationCenter: MockNotificationCenter())
        engine.start()
        engine.pause()
        engine.resume()
        XCTAssertEqual(engine.sessionState, .running)
    }

    func testTimerEngineResumeOnlyFromPaused() {
        let engine = TimerEngine(totalSeconds: 10, notificationCenter: MockNotificationCenter())
        engine.start()
        engine.resume() // running 状态调用 resume 无效
        XCTAssertEqual(engine.sessionState, .running)
    }

    func testTimerEngineReset() {
        let mock = MockNotificationCenter()
        let engine = TimerEngine(totalSeconds: 10, notificationCenter: mock)
        engine.start()
        engine.pause()
        engine.reset()
        XCTAssertEqual(engine.sessionState, .idle)
        // D1 修复：reset() 重置为 focus 默认时长（25*60）
        XCTAssertEqual(engine.remainingSeconds, SessionType.focus.defaultDuration)
        XCTAssertEqual(engine.currentSessionType, .focus)
        XCTAssertEqual(engine.sessionCount, 0)
        // 验证 reset 同时清除 pending 和 delivered 通知
        XCTAssertTrue(mock.removedPendingIdentifiers.contains("focus-complete"))
        XCTAssertTrue(mock.removedDeliveredIdentifiers.contains("focus-complete"))
    }

    func testTimerEngineResetFromRunning() {
        let engine = TimerEngine(totalSeconds: 10, notificationCenter: MockNotificationCenter())
        engine.start()
        engine.reset()
        XCTAssertEqual(engine.sessionState, .idle)
        // D1 修复：reset() 重置为 focus 默认时长（25*60）
        XCTAssertEqual(engine.remainingSeconds, SessionType.focus.defaultDuration)
    }

    func testTimerEngineBackgroundForegroundReset() {
        let engine = TimerEngine(totalSeconds: 100, notificationCenter: MockNotificationCenter())
        engine.start()
        engine.handleEnterBackground()
        // 进入后台后状态仍为 running（等待前台修正）
        XCTAssertEqual(engine.sessionState, .running)
        engine.reset()
        XCTAssertEqual(engine.sessionState, .idle)
        // D1 修复：reset() 重置为 focus 默认时长（25*60）
        XCTAssertEqual(engine.remainingSeconds, SessionType.focus.defaultDuration)
    }

    func testTimerEngineHandleEnterBackgroundOnlyWhenRunning() {
        let engine = TimerEngine(totalSeconds: 100, notificationCenter: MockNotificationCenter())
        // idle 状态进入后台无效
        engine.handleEnterBackground()
        XCTAssertEqual(engine.sessionState, .idle)
    }

    func testTimerEngineHandleForegroundWithManualCorrection() {
        let engine = TimerEngine(totalSeconds: 100, notificationCenter: MockNotificationCenter())
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

    // 验证 finishSession 幂等性：finished 状态可被 reset，reset 后可重新 start
    func testFinishSessionIdempotent() {
        let mock = MockNotificationCenter()
        let engine = TimerEngine(totalSeconds: 10, notificationCenter: mock)

        // 直接调用 finishSession 让引擎进入 finished 状态
        engine.finishSession()
        XCTAssertEqual(engine.sessionState, .finished)
        // 再次调用应为幂等（不崩溃，状态不变）
        engine.finishSession()
        XCTAssertEqual(engine.sessionState, .finished)

        // 通过 reset() 验证 finished 可以被重置
        engine.reset()
        XCTAssertEqual(engine.sessionState, .idle)
        // D1 修复：reset() 重置为 focus 默认时长（25*60）
        XCTAssertEqual(engine.remainingSeconds, SessionType.focus.defaultDuration)

        // 验证从 finished 无法 start（需先 reset）
        engine.start() // -> running
        engine.pause() // -> paused
        engine.reset() // -> idle
        engine.start() // -> running
        XCTAssertEqual(engine.sessionState, .running)
    }

    // 验证 finished 状态下调用 start 无效
    func testStartFromFinishedIsNoOp() {
        let mock = MockNotificationCenter()
        let engine = TimerEngine(totalSeconds: 1, notificationCenter: mock)
        // 直接调用 finishSession 让引擎进入 finished 状态
        engine.finishSession()
        XCTAssertEqual(engine.sessionState, .finished)
        // finished 状态下调用 start 无效（guard sessionState == .idle）
        engine.start()
        XCTAssertEqual(engine.sessionState, .finished)
    }
}

// MARK: - SessionCycleTests

@MainActor
final class SessionCycleTests: XCTestCase {

    // 测试 focus → shortBreak → focus 基本循环
    func testFocusToShortBreakToFocus() {
        let engine = TimerEngine(notificationCenter: MockNotificationCenter())
        XCTAssertEqual(engine.currentSessionType, .focus)
        XCTAssertEqual(engine.sessionCount, 0)

        // 第1次专注完成 → 短休息
        engine.advanceSession(countCompleted: true)
        XCTAssertEqual(engine.currentSessionType, .shortBreak)
        XCTAssertEqual(engine.sessionCount, 1)
        XCTAssertEqual(engine.totalSeconds, SessionType.shortBreak.defaultDuration)

        // 短休息完成 → 专注
        engine.advanceSession(countCompleted: true)
        XCTAssertEqual(engine.currentSessionType, .focus)
        XCTAssertEqual(engine.sessionCount, 1) // 短休息不增加 sessionCount
    }

    // 测试第4个番茄后进入长休息
    func testLongBreakAfterFourPomodoros() {
        let engine = TimerEngine(notificationCenter: MockNotificationCenter())

        // 完成 4 次专注（专注 → 短休 → 专注 → 短休 → 专注 → 短休 → 专注 → 长休）
        for i in 1...4 {
            XCTAssertEqual(engine.currentSessionType, .focus, "第\(i)次应为专注")
            engine.advanceSession(countCompleted: true)
            if i < 4 {
                XCTAssertEqual(engine.currentSessionType, .shortBreak, "第\(i)次专注后应为短休息")
                engine.advanceSession(countCompleted: false) // 短休息结束不计数
            }
        }

        // 第4次专注后应进入长休息
        XCTAssertEqual(engine.sessionCount, 4)
        XCTAssertEqual(engine.currentSessionType, .longBreak)
        XCTAssertEqual(engine.totalSeconds, SessionType.longBreak.defaultDuration)
    }

    // 测试 skip() 不增加 sessionCount
    func testSkipDoesNotIncrementSessionCount() {
        let engine = TimerEngine(notificationCenter: MockNotificationCenter())
        engine.start()
        let countBefore = engine.sessionCount
        engine.skip()
        XCTAssertEqual(engine.sessionCount, countBefore, "skip 不应增加 sessionCount")
        XCTAssertEqual(engine.sessionState, .idle, "skip 后状态应为 idle")
        XCTAssertEqual(engine.currentSessionType, .shortBreak, "focus skip 后应切换为 shortBreak")
    }

    // 测试 advanceSession(countCompleted: true) 增加 sessionCount（仅专注时）
    func testAdvanceSessionCountCompletedTrue() {
        let engine = TimerEngine(notificationCenter: MockNotificationCenter())
        XCTAssertEqual(engine.sessionCount, 0)
        engine.advanceSession(countCompleted: true)
        XCTAssertEqual(engine.sessionCount, 1)
    }

    // 测试 advanceSession(countCompleted: false) 不增加 sessionCount
    func testAdvanceSessionCountCompletedFalse() {
        let engine = TimerEngine(notificationCenter: MockNotificationCenter())
        XCTAssertEqual(engine.sessionCount, 0)
        engine.advanceSession(countCompleted: false)
        XCTAssertEqual(engine.sessionCount, 0)
    }

    // 测试 defaultDuration 正确性
    func testSessionTypeDefaultDuration() {
        XCTAssertEqual(SessionType.focus.defaultDuration, 25 * 60)
        XCTAssertEqual(SessionType.shortBreak.defaultDuration, 5 * 60)
        XCTAssertEqual(SessionType.longBreak.defaultDuration, 15 * 60)
    }
}
