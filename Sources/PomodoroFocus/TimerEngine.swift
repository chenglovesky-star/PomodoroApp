import Foundation
import Combine
import UserNotifications

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

    // MARK: - Private

    private var timer: AnyCancellable?
    private var backgroundEntryDate: Date?
    private let notificationCenter: any NotificationScheduling

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
        sessionState = .idle
        remainingSeconds = totalSeconds
        backgroundEntryDate = nil
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["focus-complete"])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: ["focus-complete"])
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
