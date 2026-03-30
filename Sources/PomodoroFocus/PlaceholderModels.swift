import Foundation
import SwiftData
import SwiftUI

// MARK: - FocusSession

/// 记录一次专注会话
@Model
final class FocusSession {
    var id: UUID
    var duration: Int           // 秒，必须 > 0
    var completedAt: Date
    var isCompleted: Bool
    var tag: Tag?

    init(
        duration: Int,
        completedAt: Date = Date(),
        isCompleted: Bool = false,
        tag: Tag? = nil
    ) {
        precondition(duration > 0, "duration must be greater than 0")
        self.id = UUID()
        self.duration = duration
        self.completedAt = completedAt
        self.isCompleted = isCompleted
        self.tag = tag
    }
}

// MARK: - Tag

/// 专注标签，用于分类专注会话
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
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        precondition(!trimmed.isEmpty, "Tag name cannot be empty")
        self.id = UUID()
        self.name = trimmed
        self.colorHex = colorHex
        self.sessions = []
    }
}

// MARK: - DailyRecord

/// 每日专注汇总（date 字段唯一约束）
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
        self.totalFocusSeconds = max(0, totalFocusSeconds)
        self.sessionsCount = max(0, sessionsCount)
    }
}

// MARK: - Preview

#Preview("Models Preview") {
    let schema = Schema([FocusSession.self, Tag.self, DailyRecord.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    let context = container.mainContext

    let tag = Tag(name: "工作", colorHex: "#4A90E2")
    let session = FocusSession(duration: 1500, isCompleted: true, tag: tag)
    context.insert(tag)
    context.insert(session)

    return VStack(alignment: .leading, spacing: 12) {
        Text("Tag: \(tag.name)")
            .font(.headline)
        Text("Session: \(session.duration)s, completed: \(session.isCompleted)")
            .font(.body)
            .foregroundStyle(.secondary)
    }
    .padding()
    .modelContainer(container)
}
