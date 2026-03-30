import SwiftUI

// MARK: - SessionType

/// 会话类型，用于显示标签和控制计时时长
enum SessionType: String {
    case focus = "专注"
    case shortBreak = "短休息"
    case longBreak = "长休息"
}

// MARK: - CircularTimerView

/// 圆形进度计时器 View
/// - ZStack：背景圆弧（secondary）+ 进度圆弧（accentColor）+ 中心时间文字
/// - 会话类型标签显示在计时器上方
@MainActor
struct CircularTimerView: View {
    @EnvironmentObject private var timerEngine: TimerEngine

    /// 当前会话类型（由父 View 传入，US-005 实现控制逻辑后可动态切换）
    var sessionType: SessionType = .focus

    // MARK: - 计算属性

    /// 进度值（0.0 ~ 1.0）
    private var progress: Double {
        guard timerEngine.totalSeconds > 0 else { return 1.0 }
        return Double(timerEngine.remainingSeconds) / Double(timerEngine.totalSeconds)
    }

    /// 将剩余秒数格式化为 MM:SS
    private var timeString: String {
        let minutes = timerEngine.remainingSeconds / 60
        let seconds = timerEngine.remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            // 会话类型标签
            Text(sessionType.rawValue)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .accessibilityLabel("当前会话：\(sessionType.rawValue)")

            // 圆形进度计时器
            ZStack {
                // 背景圆弧
                Circle()
                    .stroke(
                        Color.secondary.opacity(0.2),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )

                // 进度圆弧
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.accentColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: progress)

                // 中心时间文字
                VStack(spacing: 4) {
                    Text(timeString)
                        .font(.system(size: 52, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .accessibilityLabel("剩余时间：\(timeString)")
                        .accessibilityIdentifier("timerLabel")
                }
            }
            .frame(width: 220, height: 220)
        }
        .padding(.vertical, 24)
    }
}

// MARK: - Preview

#Preview("CircularTimerView - 专注") {
    CircularTimerView(sessionType: .focus)
        .environmentObject(TimerEngine())
}

#Preview("CircularTimerView - 短休息") {
    let engine = TimerEngine(totalSeconds: 5 * 60)
    return CircularTimerView(sessionType: .shortBreak)
        .environmentObject(engine)
}
