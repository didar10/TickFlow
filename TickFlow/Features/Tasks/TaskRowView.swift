import SwiftUI

/// Строка задачи: цветная полоса списка слева, срок снизу, список справа.
/// Полоса идёт на всю высоту, поэтому строке нужны нулевые `listRowInsets`.
struct TaskRowView: View {
    let task: TaskItem
    var showsListName: Bool = false
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CheckboxButton(isCompleted: task.isCompleted, priority: task.priority, action: onToggle)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                footer
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            AppColors.listColor(task.list)
                .frame(width: 3)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if let due = DateFormatting.dueRangeLabel(for: task) {
                Text(due)
                    .foregroundStyle(task.isOverdue ? Color.red : .secondary)
            }

            if task.reminderDate != nil {
                Image(systemName: "bell")
                    .foregroundStyle(.secondary)
            }

            if !task.subtasks.isEmpty {
                let done = task.subtasks.filter(\.isCompleted).count
                Text("\(done)/\(task.subtasks.count)")
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if let list = task.list, showsListName {
                Label(list.name, systemImage: list.symbolName)
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .font(.footnote)
    }
}
