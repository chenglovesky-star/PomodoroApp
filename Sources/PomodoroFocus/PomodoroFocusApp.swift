import SwiftUI
import SwiftData

@main
struct PomodoroFocusApp: App {
    let container: ModelContainer

    init() {
        let isUITesting = CommandLine.arguments.contains("--uitesting")
        let configuration = ModelConfiguration(isStoredInMemoryOnly: isUITesting)
        do {
            container = try ModelContainer(for: Schema([]), configurations: configuration)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
