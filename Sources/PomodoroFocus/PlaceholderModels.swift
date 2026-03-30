import Foundation
import SwiftData

/// 占位 Model：FocusSession（US-002 中将完整实现）
@Model
final class FocusSession {
    var id: UUID
    var duration: Int          // 秒
    var completedAt: Date
    var isCompleted: Bool
    var tag: Tag?

    init(
        id: UUID = UUID(),
        duration: Int = 1500,
        completedAt: Date = Date(),
        isCompleted: Bool = false,
        tag: Tag? = nil
    ) {
        self.id = id
        self.duration = duration
        self.completedAt = completedAt
        self.isCompleted = isCompleted
        self.tag = tag
    }
}

/// 占位 Model：Tag（US-002 中将完整实现）
@Model
final class Tag {
    var id: UUID
    var name: String
    var colorHex: String
    @Relationship(deleteRule: .nullify, inverse: \FocusSession.tag)
    var sessions: [FocusSession]

    init(
        id: UUID = UUID(),
        name: String = "",
        colorHex: String = "#FF6B6B"
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.sessions = []
    }
}

/// 占位 Model：DailyRecord（US-002 中将完整实现）
@Model
final class DailyRecord {
    var date: Date
    var totalFocusSeconds: Int
    var sessionsCount: Int

    init(
        date: Date = Date(),
        totalFocusSeconds: Int = 0,
        sessionsCount: Int = 0
    ) {
        self.date = date
        self.totalFocusSeconds = totalFocusSeconds
        self.sessionsCount = sessionsCount
    }
}
