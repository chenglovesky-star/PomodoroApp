import Foundation
import SwiftData
import SwiftUI

// MARK: - FocusSession

/// 记录一次专注会话
@Model
final class FocusSession {
    var id: UUID
    var duration: Int           // 秒，> 0
    var completedAt: Date
    var isCompleted: Bool
    var tag: Tag?

    init(
        duration: Int,
        completedAt: Date = Date(),
        isCompleted: Bool = false,
        tag: Tag? = nil
    ) {
        assert(duration > 0, "duration must be > 0")
        self.id = UUID()
        self.duration = max(1, duration)   // 生产环境静默保护
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
        assert(!trimmed.isEmpty, "Tag name cannot be empty")
        self.id = UUID()
        self.name = trimmed.isEmpty ? "未命名" : trimmed  // 生产环境静默保护
        self.colorHex = colorHex
        self.sessions = []
    }
}

// MARK: - DailyRecord

/// 每日专注汇总
/// date 存当天零点（Calendar.current.startOfDay），确保 @Attribute(.unique) 语义正确
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
        // 强制截断到当天零点，保证唯一性约束按"天"生效
        self.date = Calendar.current.startOfDay(for: date)
        self.totalFocusSeconds = max(0, totalFocusSeconds)
        self.sessionsCount = max(0, sessionsCount)
    }
}

// MARK: - Preview

#Preview("Models Preview") {
    let schema = Schema([FocusSession.self, Tag.self, DailyRecord.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: schema, configurations: [config])
    let context = container.mainContext

    let tag = Tag(name: "工作", colorHex: "#4A90E2")
    let session = FocusSession(duration: 1500, isCompleted: true, tag: tag)
    context.insert(tag)
    context.insert(session)

    return VStack(alignment: .leading, spacing: 12) {
        Text("Tag: \(tag.name)")
            .font(.headline)
        Text("Session: \(session.duration)s ✅")
            .font(.body)
            .foregroundStyle(.secondary)
        Text("DailyRecord date: \(Calendar.current.startOfDay(for: Date()).formatted(date: .abbreviated, time: .omitted))")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }
    .padding()
    .modelContainer(container)
}
