import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var timerEngine: TimerEngine
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            // 存储错误 Banner（内存降级或完全不可用时显示）
            if appState.storageInitFailed {
                StorageErrorBanner(
                    message: appState.storageErrorMessage,
                    isUnavailable: appState.storageUnavailable
                )
            }

            // 主内容区域（US-004 中替换为完整主界面）
            MainPlaceholderView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                timerEngine.handleEnterBackground()
            case .active:
                timerEngine.handleEnterForeground()
            default:
                break
            }
        }
    }
}

/// 存储错误提示 Banner
struct StorageErrorBanner: View {
    let message: String
    let isUnavailable: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isUnavailable ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isUnavailable ? .red : .orange)

            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            isUnavailable
                ? Color.red.opacity(0.12)
                : Color.orange.opacity(0.12)
        )
        .accessibilityLabel(message)
        .accessibilityAddTraits(.isStaticText)
    }
}

/// 主界面占位（US-004 中替换）
struct MainPlaceholderView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "timer")
                .font(.system(size: 80))
                .foregroundStyle(.red)
                .accessibilityHidden(true)

            Text("PomodoroFocus")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("专注番茄工作法")
                .font(.title3)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .environmentObject(TimerEngine())
}
