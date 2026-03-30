import SwiftUI
import SwiftData

// MARK: - ContentView

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

            // 主内容区域
            NavigationStack {
                TabView {
                    HomeTab()
                        .tabItem {
                            Label("专注", systemImage: "timer")
                        }
                }
                .navigationBarHidden(true)
            }
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

// MARK: - HomeTab

/// 主页 Tab：圆形计时器 + 标签选择器 + 占位控制栏
@MainActor
struct HomeTab: View {
    @State private var selectedTag: Tag? = nil
    @Query private var tags: [Tag]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 圆形进度计时器
            CircularTimerView()

            Spacer()

            // 标签选择器
            TagPickerView(selectedTag: $selectedTag)
                .accessibilityIdentifier("tagPicker")

            // 占位控制栏（US-005 实现）
            ControlBarPlaceholder()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onChange(of: tags) { _, newTags in
            if let selected = selectedTag, !newTags.contains(where: { $0.id == selected.id }) {
                selectedTag = nil
            }
        }
    }
}

// MARK: - ControlBarPlaceholder

/// 控制栏占位（US-005 实现时替换）
@MainActor
struct ControlBarPlaceholder: View {
    var body: some View {
        HStack(spacing: 32) {
            Spacer()

            Button {
                // TODO: US-005 实现
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("重置计时器")

            Button {
                // TODO: US-005 实现
            } label: {
                Image(systemName: "play.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.accentColor)
            }
            .accessibilityLabel("开始专注")
            .accessibilityIdentifier("startButton")

            Button {
                // TODO: US-005 实现
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("跳过当前会话")

            Spacer()
        }
        .padding(.vertical, 24)
        .padding(.bottom, 16)
    }
}

// MARK: - StorageErrorBanner

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

// MARK: - Preview

#Preview {
    ContentView()
        .environment(AppState())
        .environmentObject(TimerEngine())
}
