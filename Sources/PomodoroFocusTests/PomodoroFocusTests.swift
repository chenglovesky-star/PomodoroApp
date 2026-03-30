import Testing
import SwiftData
@testable import PomodoroFocus

@Suite("PomodoroFocus Unit Tests")
struct PomodoroFocusTests {

    @Test("ModelContainer 内存模式初始化成功")
    func testModelContainerMemoryInit() throws {
        let schema = Schema([FocusSession.self, Tag.self, DailyRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        #expect(container != nil)
    }

    @Test("FocusSession 创建与属性验证")
    func testFocusSessionCreation() throws {
        let schema = Schema([FocusSession.self, Tag.self, DailyRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let session = FocusSession(duration: 1500, isCompleted: false)
        context.insert(session)

        #expect(session.duration == 1500)
        #expect(session.isCompleted == false)
        #expect(session.tag == nil)
    }

    @Test("Tag 创建与关联 FocusSession")
    func testTagCreation() throws {
        let schema = Schema([FocusSession.self, Tag.self, DailyRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let tag = Tag(name: "工作", colorHex: "#FF6B6B")
        context.insert(tag)

        #expect(tag.name == "工作")
        #expect(tag.colorHex == "#FF6B6B")
        #expect(tag.sessions.isEmpty)
    }

    @Test("DailyRecord 创建")
    func testDailyRecordCreation() throws {
        let schema = Schema([FocusSession.self, Tag.self, DailyRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let record = DailyRecord(totalFocusSeconds: 3600, sessionsCount: 4)
        context.insert(record)

        #expect(record.totalFocusSeconds == 3600)
        #expect(record.sessionsCount == 4)
    }

    @Test("AppState 初始状态")
    @MainActor
    func testAppStateInitialState() {
        let state = AppState()
        #expect(state.storageInitFailed == false)
        #expect(state.storageUnavailable == false)
        #expect(state.storageErrorMessage == "")
    }

    @Test("AppState 存储降级状态设置")
    @MainActor
    func testAppStateDegradedState() {
        let state = AppState()
        state.storageInitFailed = true
        state.storageErrorMessage = "存储初始化失败，已切换为内存模式。退出 App 后数据不会保存。"
        #expect(state.storageInitFailed == true)
        #expect(state.storageUnavailable == false)
        #expect(!state.storageErrorMessage.isEmpty)
    }
}
