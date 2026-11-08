import SwiftUI

/// Строка задачи: чекбокс, приоритет и название, под ними срок, категория и значки.
struct TaskRowView: View {
    let item: TaskRowItem
    var isCompact = false
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: isCompact ? .center : .top, spacing: 12) {
            CheckCircle(
                isOn: item.isCompleted,
                tint: Color(hex: item.categoryColorHex),
                isUrgent: item.isUrgent,
                action: onToggle
            )
            .padding(.top, isCompact ? 0 : 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    if !item.priorityMarks.isEmpty {
                        Text(item.priorityMarks)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppColors.danger)
                    }
                    Text(item.title)
                        .font(AppFont.body)
                        .foregroundStyle(item.isCompleted ? AppColors.textQuaternary : AppColors.label)
                        .strikethrough(item.isCompleted)
                        .lineLimit(1)
                }

                if !isCompact {
                    meta
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, isCompact ? 9 : 13)
        .contentShape(Rectangle())
    }

    private var meta: some View {
        FlowLayout(spacing: 8, lineSpacing: 3) {
            Text(item.meta)
                .foregroundStyle(item.isOverdue ? AppColors.danger : AppColors.textTertiary)
                .fontWeight(item.isOverdue ? .medium : .regular)

            HStack(spacing: 4) {
                Circle()
                    .fill(Color(hex: item.categoryColorHex))
                    .frame(width: 7, height: 7)
                Text(item.categoryName)
            }

            if let progress = item.subtaskProgress {
                Label(progress, systemImage: "list.bullet")
                    .labelStyle(CompactLabelStyle())
            }
            if item.hasReminder {
                Image(systemName: "bell").font(.system(size: 11))
            }
            if item.isRepeating {
                Image(systemName: "repeat").font(.system(size: 11))
            }
            if item.hasConflict {
                Label(L10n.Common.overlap, systemImage: "exclamationmark.triangle")
                    .labelStyle(CompactLabelStyle())
                    .foregroundStyle(AppColors.warningText)
                    .fontWeight(.medium)
            }
        }
        .font(AppFont.footnote)
        .foregroundStyle(AppColors.textTertiary)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Значок и текст вплотную, как в метаданных строки.
struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.font(.system(size: 11, weight: .semibold))
            configuration.title
        }
    }
}
