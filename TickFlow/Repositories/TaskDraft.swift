import Foundation

/// Значения задачи для сохранения. Экран редактирует черновик, а не модель,
/// поэтому «Отмена» ничего не меняет в базе.
struct TaskDraft {
    var title: String
    var notes: String
    var dueDate: Date?
    var hasTime: Bool
    var durationMinutes: Int
    /// Последний день многодневной задачи. `nil` — один день.
    var endDay: Date?
    var priority: Priority
    var reminder: ReminderOption
    var repeatRule: RepeatRule
    var list: TaskList?
    var subtasks: [SubtaskDraft]
    var isCompleted = false
    /// Трекинг времени задачи. `nil` — как у категории.
    var trackingOverride: Bool? = nil
    /// Своя оценка в минутах. `nil` — длительность слота, `0` — без оценки.
    var estimateMinutes: Int? = nil
}

struct SubtaskDraft: Identifiable, Hashable {
    let id: UUID
    var title: String
    var isCompleted: Bool
}

struct TaskListDraft {
    var name: String
    var colorHex: String
    var symbolName: String
    var tracksTimeByDefault = false
}

/// Полный снимок задачи. Нужен для «Отменить»: восстановить после удаления или правки.
struct TaskSnapshot {
    let id: UUID
    let draft: TaskDraft
    let completedAt: Date?
    let createdAt: Date
    let sortOrder: Int
    /// Записи времени задачи: при восстановлении удалённой задачи связь с ними возвращается.
    let timeEntryIDs: [UUID]

    @MainActor
    init(_ task: TaskItem) {
        id = task.id
        completedAt = task.completedAt
        createdAt = task.createdAt
        sortOrder = task.sortOrder
        timeEntryIDs = task.timeEntries.map(\.id)
        draft = TaskDraft(
            title: task.title,
            notes: task.notes,
            dueDate: task.dueDate,
            hasTime: task.hasTime,
            durationMinutes: task.durationMinutes,
            endDay: task.endDay,
            priority: task.priority,
            reminder: task.reminder,
            repeatRule: task.repeatRule,
            list: task.list,
            subtasks: task.sortedSubtasks.map {
                SubtaskDraft(id: $0.id, title: $0.title, isCompleted: $0.isCompleted)
            },
            isCompleted: task.isCompleted,
            trackingOverride: task.trackingOverride,
            estimateMinutes: task.estimateMinutes
        )
    }
}
