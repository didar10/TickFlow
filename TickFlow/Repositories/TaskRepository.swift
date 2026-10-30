import Foundation

/// Доступ к задачам. `tasks` наблюдаем: экран обновится после любого изменения.
@MainActor
protocol TaskRepository: AnyObject {
    /// Все задачи по `sortOrder`, затем по дате создания.
    var tasks: [TaskItem] { get }

    func insert(_ tasks: [TaskItem])
    func save(_ draft: TaskDraft, to task: TaskItem?)
    func setCompleted(_ task: TaskItem, _ isCompleted: Bool)
    func delete(_ task: TaskItem)
    /// Назначает начало. Задача без времени становится задачей со временем.
    func schedule(_ task: TaskItem, at start: Date)
    func setDuration(_ task: TaskItem, minutes: Int)
    func moveToToday(_ task: TaskItem)
}
