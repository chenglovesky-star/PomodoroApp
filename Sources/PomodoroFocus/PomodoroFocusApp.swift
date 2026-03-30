import SwiftUI
import SwiftData
import UserNotifications

// MARK: - NotificationDelegate

/// 前台通知代理：确保 App 在前台时通知 banner/声音正常展示
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

@main
struct PomodoroFocusApp: App {
    /// App 级状态，通过 .environment 注入到 View 层（方案B）
    private let appState = AppState()

    /// 计时器引擎，通过 .environmentObject 注入到 View 层
    @StateObject private var timerEngine = TimerEngine()

    /// 通知代理（必须强引用持有，否则会被释放）
    private let notificationDelegate = NotificationDelegate()

    let container: ModelContainer

    init() {
        // 设置前台通知代理
        UNUserNotificationCenter.current().delegate = notificationDelegate

        let schema = Schema([FocusSession.self, Tag.self, DailyRecord.self])
        let isUITesting = CommandLine.arguments.contains("--uitesting")

        // 尝试磁盘存储（UITest 时直接使用内存模式）
        if let diskContainer = try? ModelContainer(
            for: schema,
            configurations: [
                ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: isUITesting
                )
            ]
        ) {
            container = diskContainer
        }
        // 降级：内存模式
        else if let memContainer = try? ModelContainer(
            for: schema,
            configurations: [
                ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
            ]
        ) {
            container = memContainer
            // 在 init 中设置 static 标志，body 中传入 appState
            PomodoroFocusApp.pendingStorageError = .degradedToMemory
        }
        // 完全无法初始化：使用最小化空 container，保持 App 可运行
        else {
            // 最后手段：空 Schema 内存 container，确保 App 不崩溃
            let fallbackSchema = Schema([FocusSession.self, Tag.self, DailyRecord.self])
            if let fallback = try? ModelContainer(
                for: fallbackSchema,
                configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
            ) {
                container = fallback
            } else {
                // 极端情况：创建最小 container
                // swiftlint:disable:next force_try
                container = try! ModelContainer(
                    for: Schema([]),
                    configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
                )
            }
            PomodoroFocusApp.pendingStorageError = .unavailable
        }
    }

    // 用 static 变量在 init() 与 body 之间传递初始化结果
    private static var pendingStorageError: StorageErrorKind?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environmentObject(timerEngine)
                .task {
                    // 请求通知权限（US-003）
                    timerEngine.requestNotificationPermission()
                    // 在 body（MainActor 上下文）中安全地更新 @Observable AppState
                    if let errorKind = PomodoroFocusApp.pendingStorageError {
                        switch errorKind {
                        case .degradedToMemory:
                            appState.storageInitFailed = true
                            appState.storageErrorMessage = "存储初始化失败，已切换为内存模式。退出 App 后数据不会保存。"
                        case .unavailable:
                            appState.storageInitFailed = true
                            appState.storageUnavailable = true
                            appState.storageErrorMessage = "存储不可用，当前为只读模式。"
                        }
                        PomodoroFocusApp.pendingStorageError = nil
                    }
                }
        }
        .modelContainer(container)
    }
}

private enum StorageErrorKind {
    case degradedToMemory
    case unavailable
}
