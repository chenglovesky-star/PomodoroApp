import SwiftUI
import SwiftData

// MARK: - Color+Hex 扩展

extension Color {
    /// 从 #RRGGBB 格式的十六进制字符串初始化颜色
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard hex.count == 6 else { self = .gray; return }
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int) else { self = .gray; return }
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b)
    }
}

// MARK: - TagPickerView

/// 横向滚动标签选择器
/// - 通过 @Query 获取所有 Tag
/// - 第一个选项始终为「无标签」
/// - 选中时用 tag.colorHex 高亮，未选中时使用 secondary 样式
@MainActor
struct TagPickerView: View {
    @Query(sort: \Tag.name) private var tags: [Tag]

    /// 当前选中的标签，nil 表示「无标签」
    @Binding var selectedTag: Tag?

    // MARK: - Body

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 「无标签」选项
                noTagButton

                // 空标签提示（仅当无标签时显示）
                if tags.isEmpty {
                    Text("前往设置创建标签")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // 动态标签列表
                ForEach(tags) { tag in
                    tagButton(for: tag)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .accessibilityIdentifier("tagPickerScrollView")
    }

    // MARK: - 子视图

    /// 「无标签」选项按钮
    private var noTagButton: some View {
        let isSelected = selectedTag == nil
        return Button {
            selectedTag = nil
        } label: {
            Text("无标签")
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("无标签")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("tagButton_none")
    }

    /// 标签选项按钮
    private func tagButton(for tag: Tag) -> some View {
        let isSelected = selectedTag?.id == tag.id
        let tagColor = Color(hex: tag.colorHex)
        return Button {
            selectedTag = tag
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(tagColor)
                    .frame(width: 8, height: 8)

                Text(tag.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? tagColor : .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? tagColor.opacity(0.15) : Color.secondary.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? tagColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tag.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("tagButton_\(tag.name)")
    }
}

// MARK: - Preview

#Preview("TagPickerView - 有标签") {
    let schema = Schema([Tag.self, FocusSession.self, DailyRecord.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: schema, configurations: [config])
    let context = container.mainContext

    let tag1 = Tag(name: "工作", colorHex: "#4A90E2")
    let tag2 = Tag(name: "学习", colorHex: "#7ED321")
    let tag3 = Tag(name: "运动", colorHex: "#FF6B6B")
    context.insert(tag1)
    context.insert(tag2)
    context.insert(tag3)

    return TagPickerPreviewWrapper()
        .modelContainer(container)
}

/// Preview 辅助 Wrapper，持有 @State selectedTag
@MainActor
private struct TagPickerPreviewWrapper: View {
    @State private var selectedTag: Tag? = nil

    var body: some View {
        VStack {
            TagPickerView(selectedTag: $selectedTag)
            Text(selectedTag.map { "已选：\($0.name)" } ?? "已选：无标签")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }
}
