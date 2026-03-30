import SwiftUI
import UIKit

// MARK: - ControlBarView

/// 控制栏：开始/暂停/重置/跳过按钮 + 番茄计数
@MainActor
struct ControlBarView: View {
    @EnvironmentObject private var timerEngine: TimerEngine

    var body: some View {
        VStack(spacing: 8) {
            // 番茄计数（显示当前第几个番茄）
            Text("第 \(timerEngine.sessionCount + 1) 个番茄")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("第 \(timerEngine.sessionCount + 1) 个番茄")

            HStack(spacing: 32) {
                // 重置按钮
                Button {
                    resetWithHaptic()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("重置计时器")
                .accessibilityIdentifier("resetButton")

                // 开始/暂停按钮
                Button {
                    toggleWithHaptic()
                } label: {
                    Image(systemName: playPauseIcon)
                        .font(.system(size: 56))
                        .foregroundStyle(Color.accentColor)
                }
                .accessibilityLabel(playPauseLabel)
                .accessibilityIdentifier("startButton")

                // 跳过按钮
                Button {
                    skipWithHaptic()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("跳过当前会话")
                .accessibilityIdentifier("skipButton")
            }
        }
        .padding(.vertical, 24)
        .padding(.bottom, 16)
    }

    // MARK: - 计算属性

    private var playPauseIcon: String {
        switch timerEngine.sessionState {
        case .running: return "pause.fill"
        case .finished: return "arrow.clockwise"
        default: return "play.fill"
        }
    }

    private var playPauseLabel: String {
        switch timerEngine.sessionState {
        case .running: return "暂停专注"
        case .finished: return "开始下一个"
        default: return "开始专注"
        }
    }

    // MARK: - 操作（含触觉反馈）

    private func toggleWithHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        switch timerEngine.sessionState {
        case .idle:
            timerEngine.start()
        case .running:
            timerEngine.pause()
        case .paused:
            timerEngine.resume()
        case .finished:
            timerEngine.reset()
            timerEngine.start()
        }
    }

    private func resetWithHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        timerEngine.reset()
    }

    private func skipWithHaptic() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        timerEngine.skip()
    }
}

// MARK: - Preview

#Preview("ControlBarView - 空闲") {
    ControlBarView()
        .environmentObject(TimerEngine())
}

#Preview("ControlBarView - 运行中") {
    let engine = TimerEngine()
    engine.start()
    return ControlBarView()
        .environmentObject(engine)
}
