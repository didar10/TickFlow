import Foundation

/// Доступ к задачам. `tasks` наблюдаем: экран обновится после любого изменения.
@MainActor
protocol TaskRepository: AnyObject {
    /// Все задачи по `sortOrder`, затем по дате создания.
    var tasks: [TaskItem] { get }

    func insert(_ tasks: [TaskItem])
    @discardableResult
    func save(_ draft: TaskDraft, to task: TaskItem?) -> TaskItem
    /// Отмечает задачу. Для повторяющейся при выполнении создаётся следующее вхождение,
    /// оно и возвращается (нужно, чтобы «Отменить» его убрало).
    @discardableResult
    func setCompleted(_ task: TaskItem, _ isCompleted: Bool) -> TaskItem?
    func delete(_ task: TaskItem)
    @discardableResult
    func duplicate(_ task: TaskItem) -> TaskItem
    /// Возвращает задачу к состоянию снимка; удалённая создаётся заново с тем же id.
    func restore(_ snapshot: TaskSnapshot)
    /// Назначает начало. Задача без времени становится задачей со временем.
    func schedule(_ task: TaskItem, at start: Date)
    func setDuration(_ task: TaskItem, minutes: Int)
    /// Меняет дни задачи без времени: перенос или растягивание многодневной.
    func setDays(_ task: TaskItem, start: Date, end: Date)
    func moveToToday(_ task: TaskItem)
    /// Перепланирует напоминания всех задач (например, после смены настроек).
    func rescheduleReminders(enabled: Bool)
}
