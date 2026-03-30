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
        self.id = UUID()
        self.duration = max(1, duration)   // 最小 1 秒，由 UI 层保证合法输入
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
        self.id = UUID()
        self.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? "未命名" : name.trimmingCharacters(in: .whitespaces)
        self.colorHex = colorHex
        self.sessions = []
    }
}

// MARK: - DailyRecord

/// 每日专注汇总（反范式化缓存，由 TimerEngine 在会话结束时更新）
/// - date：当天零点，@Attribute(.unique) 确保每天只有一条记录
/// - totalFocusSeconds / sessionsCount：由 TimerEngine.completeSession() 累加写入
/// - 设计原因：避免每次统计时全量查询 FocusSession，提升图表渲染性能
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
        // 使用明确绑定时区的 Calendar，避免系统时区变更导致的日期漂移
        self.date = DailyRecord.startOfDay(for: date)
        self.totalFocusSeconds = max(0, totalFocusSeconds)
        self.sessionsCount = max(0, sessionsCount)
    }

    /// 返回指定日期当天的零点时刻
    /// 明确绑定 TimeZone.current，避免全局 Calendar.current 因系统时区切换产生漂移
    private static func startOfDay(for date: Date) -> Date {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current  // 明确绑定，不依赖全局 Calendar.current
        return cal.startOfDay(for: date)
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
