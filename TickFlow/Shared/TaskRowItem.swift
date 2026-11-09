import Foundation

/// Готовые данные строки задачи: View только рисует их, ничего не вычисляя.
struct TaskRowItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    /// "!", "!!", "!!!" — пусто, если приоритета нет.
    let priorityMarks: String
    let meta: String
    let isOverdue: Bool
    let categoryName: String
    let categoryColorHex: String
    /// "1/3" или `nil`, если подзадач нет.
    let subtaskProgress: String?
    let hasReminder: Bool
    let isRepeating: Bool
    let hasConflict: Bool
    let isCompleted: Bool
    let isUrgent: Bool

    @MainActor
    init(task: TaskItem, format: DisplayFormatter, allTasks: [TaskItem], meta: String? = nil) {
        id = task.id
        title = task.title
        priorityMarks = task.priority.marks
        self.meta = meta ?? format.dueLabel(for: task)
        isOverdue = task.isOverdue(now: format.now, calendar: format.calendar)
        categoryName = task.list?.name ?? L10n.Common.noCategory
        categoryColorHex = task.list?.colorHex ?? AppColors.fallbackList
        subtaskProgress = task.subtasks.isEmpty ? nil : "\(task.completedSubtaskCount)/\(task.subtasks.count)"
        hasReminder = task.reminder != .none && task.dueDate != nil
        isRepeating = task.repeatRule != .never
        hasConflict = ConflictDetector.conflict(for: task, in: allTasks, calendar: format.calendar) != nil
        isCompleted = task.isCompleted
        isUrgent = task.priority == .high
    }
}
