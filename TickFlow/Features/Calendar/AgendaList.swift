import SwiftUI

/// Задачи выбранного дня по порядку: время слева, карточка справа.
struct AgendaList: View {
    let tasks: [TaskItem]
    let onSelect: (TaskItem) -> Void
    let onToggle: (TaskItem) -> Void
    let onDelete: (TaskItem) -> Void

    var body: some View {
        List {
            ForEach(tasks) { task in
                row(task, isLast: task.id == tasks.last?.id)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(task) }
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            onDelete(task)
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .contentMargins(.bottom, 88, for: .scrollContent)
        .screenBackground()
        .overlay {
            if tasks.isEmpty {
                ContentUnavailableView(
                    "На этот день задач нет",
                    systemImage: "calendar",
                    description: Text("Добавьте задачу кнопкой «плюс».")
                )
            }
        }
    }

    private func row(_ task: TaskItem, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 6) {
                Text(timeLabel(task))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)

                if !isLast {
                    Rectangle()
                        .fill(AppColors.hairline)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 42)

            card(task)
                .padding(.bottom, 10)
        }
    }

    private func card(_ task: TaskItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(DateFormatting.timeRange(for: task) ?? "Весь день")
                    .font(.footnote)
                    .foregroundStyle(Color.accentColor)

                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            CheckboxButton(isCompleted: task.isCompleted, priority: task.priority) {
                onToggle(task)
            }
        }
        .padding(12)
        .background(AppColors.surface, in: .rect(cornerRadius: 12))
    }

    private func timeLabel(_ task: TaskItem) -> String {
        guard task.hasTime, let due = task.dueDate else { return "Весь\nдень" }
        return DateFormatting.time(for: due)
    }
}
