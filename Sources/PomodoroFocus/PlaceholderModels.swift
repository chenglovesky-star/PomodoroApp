import Foundation
import SwiftData

/// 占位 Model — US-002 将替换为完整实现
@Model
final class FocusSession {
    var id: UUID
    var duration: Int
    var completedAt: Date
    var isCompleted: Bool

    init(id: UUID = UUID(), duration: Int = 1500, completedAt: Date = Date(), isCompleted: Bool = false) {
        self.id = id
        self.duration = duration
        self.completedAt = completedAt
        self.isCompleted = isCompleted
    }
}

@Model
final class Tag {
    var id: UUID
    var name: String
    var colorHex: String

    init(id: UUID = UUID(), name: String = "", colorHex: String = "#FF6B6B") {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
}

@Model
final class DailyRecord {
    var date: Date
    var totalFocusSeconds: Int
    var sessionsCount: Int

    init(date: Date = Date(), totalFocusSeconds: Int = 0, sessionsCount: Int = 0) {
        self.date = date
        self.totalFocusSeconds = totalFocusSeconds
        self.sessionsCount = sessionsCount
    }
}
