import Foundation
import SwiftData

/// FocusSession：记录一次专注会话
@Model
final class FocusSession {
    var id: UUID
    var duration: Int           // 秒
    var completedAt: Date
    var isCompleted: Bool
    var tag: Tag?

    init(
        duration: Int,
        completedAt: Date = Date(),
        isCompleted: Bool = false,
        tag: Tag? = nil
    ) {
        self.id = UUID()
        self.duration = duration
        self.completedAt = completedAt
        self.isCompleted = isCompleted
        self.tag = tag
    }
}

/// Tag：专注标签分类
@Model
final class Tag {
    var id: UUID
    var name: String
    var colorHex: String
    @Relationship(deleteRule: .nullify, inverse: \FocusSession.tag)
    var sessions: [FocusSession]

    init(
        name: String,
        colorHex: String = "#FF6B6B"
    ) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.sessions = []
    }
}

/// DailyRecord：每日汇总记录（date 唯一约束）
@Model
final class DailyRecord {
    @Attribute(.unique) var date: Date
    var totalFocusSeconds: Int
    var sessionsCount: Int

    init(
        date: Date,
        totalFocusSeconds: Int = 0,
        sessionsCount: Int = 0
    ) {
        self.date = date
        self.totalFocusSeconds = totalFocusSeconds
        self.sessionsCount = sessionsCount
    }
}
