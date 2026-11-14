import Foundation

/// Значения записи времени для сохранения.
struct TimeEntryDraft {
    var task: TaskItem?
    var start: Date
    var end: Date
    var kind: TimeEntryKind
    var status: TimeEntryStatus = .completed

    /// Конец позже начала — иначе запись не сохраняется.
    var isValid: Bool { end > start }
}

/// Доступ к записям времени. `entries` наблюдаем: экран обновится после любого изменения.
@MainActor
protocol TimeEntryRepository: AnyObject {
    /// Все записи по началу.
    var entries: [TimeEntry] { get }

    /// Сохраняет новую запись. Запись, у которой конец не позже начала, не сохраняется.
    @discardableResult
    func add(_ draft: TimeEntryDraft) -> TimeEntry?
    /// Сохраняет сразу много записей одним сохранением (пример данных). Неверные пропускаются.
    func insert(_ drafts: [TimeEntryDraft])
    /// Меняет задачу, время и статус. Тип записи не меняется.
    func update(_ entry: TimeEntry, with draft: TimeEntryDraft)
    func delete(_ entry: TimeEntry)
}

extension TimeEntryRepository {
    /// Записи задачи, новые сверху.
    func entries(for task: TaskItem) -> [TimeEntry] {
        entries.filter { $0.task?.id == task.id }.sorted { $0.start > $1.start }
    }

    /// Записи, начавшиеся в этот день.
    func entries(on day: Date, calendar: Calendar) -> [TimeEntry] {
        entries.filter { calendar.isDate($0.start, inSameDayAs: day) }
    }
}
