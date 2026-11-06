import Foundation

/// Значения задачи для сохранения. Экран редактирует черновик, а не модель,
/// поэтому «Отмена» ничего не меняет в базе.
struct TaskDraft {
    var title: String
    var notes: String
    var dueDate: Date?
    var hasTime: Bool
    var durationMinutes: Int
    var priority: Priority
    var list: TaskList?
    var subtasks: [SubtaskDraft]
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
}
