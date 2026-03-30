import Foundation
import Combine
import UserNotifications
import UIKit

// MARK: - NotificationScheduling Protocol

/// 通知调度协议，便于测试时注入 mock
protocol NotificationScheduling {
    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?)
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping @Sendable (Bool, Error?) -> Void)
}

extension UNUserNotificationCenter: NotificationScheduling {}

// MARK: - TimerEngine

/// 番茄计时器引擎
/// - 状态机：idle → running ⇄ paused → finished
/// - 后台保活：进入后台记录时间戳，回到前台时修正剩余时间
/// - 本地通知：专注结束时推送「专注完成 🎉」
@MainActor
final class TimerEngine: ObservableObject {

    // MARK: - State

    enum SessionState: Equatable {
        case idle, running, paused, finished
    }

    @Published var sessionState: SessionState = .idle
    @Published var remainingSeconds: Int
    @Published var totalSeconds: Int
    @Published var sessionCount: Int = 0          // 已完成的番茄数
    @Published var currentSessionType: SessionType = .focus  // 当前会话类型

    // MARK: - Private

    private var timer: AnyCancellable?
    private var backgroundEntryDate: Date?
    private let notificationCenter: any NotificationScheduling
    private var autoAdvanceTask: Task<Void, Never>?

    // MARK: - Init（依赖注入 notificationCenter，方便测试时 mock）

    init(
        totalSeconds: Int = 25 * 60,
        notificationCenter: any NotificationScheduling = UNUserNotificationCenter.current()
    ) {
        self.totalSeconds = totalSeconds
        self.remainingSeconds = totalSeconds
        self.notificationCenter = notificationCenter
    }

    // MARK: - Public API

    func start() {
        guard sessionState == .idle else { return }
        sessionState = .running
        scheduleTimer()
    }

    func pause() {
        guard sessionState == .running else { return }
        sessionState = .paused
        timer?.cancel()
    }

    func resume() {
        guard sessionState == .paused else { return }
        sessionState = .running
        scheduleTimer()
    }

    func reset() {
        timer?.cancel()
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
        sessionState = .idle
        currentSessionType = .focus
        sessionCount = 0
        totalSeconds = SessionType.focus.defaultDuration
        remainingSeconds = totalSeconds
        backgroundEntryDate = nil
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["focus-complete"])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: ["focus-complete"])
    }

    /// 跳过当前会话，不计入 sessionCount
    func skip() {
        guard sessionState != .idle else { return }
        timer?.cancel()
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["focus-complete"])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: ["focus-complete"])
        backgroundEntryDate = nil
        advanceSession(countCompleted: false)
        sessionState = .idle
    }

    /// 在 .finished 状态下手动跳过自动推进延迟，直接进入下一个会话
    func skipToNextSession() {
        guard sessionState == .finished else { return }
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        advanceSession(countCompleted: true)
        sessionState = .idle
        start()
    }

    // MARK: - 后台保活

    /// 进入后台时调用：停止 timer，记录进入时刻
    func handleEnterBackground() {
        guard sessionState == .running, backgroundEntryDate == nil else { return }
        backgroundEntryDate = Date()
        timer?.cancel()
    }

    /// 回到前台时调用：根据实际流逝时间修正剩余秒数
    func handleEnterForeground() {
        guard sessionState == .running, let entry = backgroundEntryDate else { return }
        let elapsed = Int(Date().timeIntervalSince(entry))
        remainingSeconds = max(0, remainingSeconds - elapsed)
        backgroundEntryDate = nil
        if remainingSeconds == 0 {
            finishSession()
        } else {
            scheduleTimer()
        }
    }

    // MARK: - 通知权限

    /// 请求通知权限，在 App 启动时调用
    func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Private

    private func scheduleTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.remainingSeconds > 0 {
                    self.remainingSeconds -= 1
                } else {
                    self.finishSession()
                }
            }
    }

    func finishSession() {
        guard sessionState != .finished else { return }  // 幂等保护
        timer?.cancel()
        sessionState = .finished
        scheduleNotification()
        // 延迟 1.5 秒后自动进入下一个会话
        autoAdvanceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard let self, self.sessionState == .finished else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()  // 会话切换触觉反馈
            self.advanceSession(countCompleted: true)
            self.sessionState = .idle
            self.start()
        }
    }

    // MARK: - 会话循环

    /// 计算并切换到下一个会话类型，可选是否计入完成数
    func advanceSession(countCompleted: Bool) {
        if countCompleted && currentSessionType == .focus {
            sessionCount += 1
        }
        // 循环规则：每4个专注后是长休息，其他是短休息
        let nextType: SessionType
        if currentSessionType == .focus {
            nextType = (sessionCount % 4 == 0 && sessionCount > 0) ? .longBreak : .shortBreak
        } else {
            nextType = .focus
        }
        currentSessionType = nextType
        totalSeconds = nextType.defaultDuration
        remainingSeconds = totalSeconds
    }

    private func scheduleNotification() {
        let content = UNMutableNotificationContent()
        content.title = "专注完成 🎉"
        content.body = "休息一下，你做得很棒！"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "focus-complete",
            content: content,
            trigger: nil   // 立即发送
        )
        notificationCenter.add(request, withCompletionHandler: nil)
    }
}
