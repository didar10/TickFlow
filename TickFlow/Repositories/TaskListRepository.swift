import Foundation

/// Доступ к спискам. `lists` наблюдаем: экран обновится после любого изменения.
@MainActor
protocol TaskListRepository: AnyObject {
    /// Все списки по `sortOrder`.
    var lists: [TaskList] { get }

    func insert(_ lists: [TaskList])
    /// Возвращает сохранённую категорию: новую или ту же.
    @discardableResult
    func save(_ draft: TaskListDraft, to list: TaskList?) -> TaskList
    func delete(_ list: TaskList)
}
