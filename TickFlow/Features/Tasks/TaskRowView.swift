import SwiftUI

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

                if !metadata.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(metadata, id: \.self) { item in
                            Text(item)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(task.isOverdue ? Color.red : .secondary)
                }
            }

            Spacer(minLength: 0)

            if task.priority != .none {
                Image(systemName: task.priority.symbolName)
                    .font(.caption)
                    .foregroundStyle(task.priority.color)
            }

            if let list = task.list, showsListName {
                Circle()
                    .fill(Color(hex: list.colorHex))
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            }
        }
        .padding(.vertical, 2)
    }

    private var metadata: [String] {
        var items: [String] = []
        if let due = task.dueDate {
            items.append(DateFormatting.dueLabel(for: due, hasTime: task.hasTime))
        }
        if !task.subtasks.isEmpty {
            let done = task.subtasks.filter(\.isCompleted).count
            items.append("\(done)/\(task.subtasks.count)")
        }
        if let list = task.list, showsListName {
            items.append(list.name)
        }
        if !task.notes.isEmpty {
            items.append("Заметка")
        }
        return items
    }
}
