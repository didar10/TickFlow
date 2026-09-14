import SwiftData
import SwiftUI

/// Создание и редактирование задачи. Новая задача попадает в базу только после «Готово».
struct TaskEditorView: View {
    let task: TaskItem?
    var defaultList: TaskList?
    var defaultDueDate: Date?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \TaskList.sortOrder) private var lists: [TaskList]

    @State private var title = ""
    @State private var notes = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date.now
    @State private var hasTime = false
    @State private var priority: Priority = .none
    @State private var selectedListID: UUID?
    @State private var subtasks: [SubtaskDraft] = []
    @State private var newSubtaskTitle = ""
    @State private var didLoad = false

    struct SubtaskDraft: Identifiable, Hashable {
        let id: UUID
        var title: String
        var isCompleted: Bool
        /// true, если объекта ещё нет в базе.
        var isNew: Bool
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название", text: $title, axis: .vertical)
                        .font(.headline)
                    TextField("Заметки", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Срок") {
                    Toggle("Дата", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker(
                            "День",
                            selection: $dueDate,
                            displayedComponents: hasTime ? [.date, .hourAndMinute] : [.date]
                        )
                        Toggle("Указать время", isOn: $hasTime.animation())
                        if hasTime {
                            Label(
                                "Придёт локальное уведомление",
                                systemImage: "bell"
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Picker("Список", selection: $selectedListID) {
                        Text("Без списка").tag(UUID?.none)
                        ForEach(lists) { list in
                            Text(list.name).tag(UUID?.some(list.id))
                        }
                    }

                    Picker("Приоритет", selection: $priority) {
                        ForEach(Priority.allCases) { value in
                            Label(value.title, systemImage: value.symbolName)
                                .tag(value)
                        }
                    }
                }

                Section("Подзадачи") {
                    ForEach($subtasks) { $subtask in
                        HStack(spacing: 12) {
                            Button {
                                subtask.isCompleted.toggle()
                            } label: {
                                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(subtask.isCompleted ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                            }
                            .buttonStyle(.plain)

                            TextField("Подзадача", text: $subtask.title)
                                .strikethrough(subtask.isCompleted)
                        }
                    }
                    .onDelete { offsets in
                        subtasks.remove(atOffsets: offsets)
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.tint)
                        TextField("Новая подзадача", text: $newSubtaskTitle)
                            .onSubmit(addSubtask)
                    }
                }

                if let task {
                    Section {
                        Button(role: .destructive) {
                            deleteTask(task)
                        } label: {
                            Label("Удалить задачу", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(task == nil ? "Новая задача" : "Задача")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    // MARK: - Загрузка и сохранение

    private func load() {
        // onAppear может сработать повторно — не затираем то, что пользователь уже ввёл.
        guard !didLoad else { return }
        didLoad = true

        if let task {
            title = task.title
            notes = task.notes
            hasDueDate = task.dueDate != nil
            dueDate = task.dueDate ?? defaultDueDate ?? .now
            hasTime = task.hasTime
            priority = task.priority
            selectedListID = task.list?.id
            subtasks = task.sortedSubtasks.map {
                SubtaskDraft(id: $0.id, title: $0.title, isCompleted: $0.isCompleted, isNew: false)
            }
        } else {
            hasDueDate = defaultDueDate != nil
            dueDate = defaultDueDate ?? .now
            selectedListID = defaultList?.id ?? lists.first?.id
        }
    }

    private func addSubtask() {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        subtasks.append(SubtaskDraft(id: UUID(), title: trimmed, isCompleted: false, isNew: true))
        newSubtaskTitle = ""
    }

    private func save() {
        addSubtask()

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let calendar = Calendar.current
        let item: TaskItem

        if let task {
            item = task
        } else {
            item = TaskItem(title: trimmed)
            context.insert(item)
        }

        item.title = trimmed
        item.notes = notes
        item.priority = priority
        item.hasTime = hasDueDate && hasTime
        item.dueDate = hasDueDate
            ? (hasTime ? dueDate : calendar.startOfDay(for: dueDate))
            : nil
        item.list = lists.first { $0.id == selectedListID }

        syncSubtasks(on: item)

        try? context.save()
        NotificationScheduler.reschedule(id: item.id, title: item.title, fireDate: item.reminderDate)
        dismiss()
    }

    private func syncSubtasks(on item: TaskItem) {
        let drafts = subtasks.filter {
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let keptIDs = Set(drafts.map(\.id))

        for existing in item.subtasks where !keptIDs.contains(existing.id) {
            context.delete(existing)
        }

        for (index, draft) in drafts.enumerated() {
            if let existing = item.subtasks.first(where: { $0.id == draft.id }) {
                existing.title = draft.title
                existing.isCompleted = draft.isCompleted
                existing.sortOrder = index
            } else {
                let subtask = Subtask(
                    title: draft.title,
                    isCompleted: draft.isCompleted,
                    sortOrder: index
                )
                subtask.parent = item
                context.insert(subtask)
            }
        }
    }

    private func deleteTask(_ task: TaskItem) {
        NotificationScheduler.cancel(taskID: task.id)
        context.delete(task)
        try? context.save()
        dismiss()
    }
}
