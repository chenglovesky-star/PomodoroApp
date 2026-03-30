import SwiftUI
import SwiftData

@main
struct PomodoroFocusApp: App {
    let container: ModelContainer
    @State private var showStorageError: Bool = false

    init() {
        let schema = Schema([
            FocusSession.self,
            Tag.self,
            DailyRecord.self
        ])

        let isUITesting = CommandLine.arguments.contains("--uitesting")

        do {
            let config: ModelConfiguration
            if isUITesting {
                config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            } else {
                config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            }
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // 降级到内存模式，避免 fatalError 硬崩溃
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = (try? ModelContainer(for: schema, configurations: [memoryConfig]))
                ?? { fatalError("内存模式 ModelContainer 初始化失败：\(error)") }()
            // 注意：此处 showStorageError 在 init 中无法直接设置 @State
            // 通过 AppStorage 传递错误标志
            UserDefaults.standard.set(true, forKey: "storageInitFailed")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(showStorageError: UserDefaults.standard.bool(forKey: "storageInitFailed"))
                .modelContainer(container)
                .onAppear {
                    // 清除标志，只在本次启动显示一次 banner
                    UserDefaults.standard.removeObject(forKey: "storageInitFailed")
                }
        }
    }
}
