import SwiftUI

/// App 级别状态管理，通过 .environment 注入到 View 层
/// 使用 @Observable 替代 ObservableObject，符合 Swift 5.9+ 最佳实践
@Observable
@MainActor
final class AppState {
    /// 存储初始化是否失败（磁盘模式降级为内存模式时为 true）
    var storageInitFailed: Bool = false

    /// 存储是否完全不可用（连内存模式也失败时为 true）
    var storageUnavailable: Bool = false

    /// 当前存储模式描述（用于 banner 提示）
    var storageErrorMessage: String = ""
}
