import Foundation
import Observation
import OSLog
import SwiftData

/// Единственное место, которое знает про SwiftData и напоминания задач.
/// Один класс на оба протокола: удаление списка каскадно меняет и задачи,
/// поэтому кэши должны обновляться вместе.
@MainActor
@Observable
final class SwiftDataRepository: TaskRepository, TaskListRepository {
    private(set) var tasks: [TaskItem] = []
    private(set) var lists: [TaskList] = []

    /// Выключено в настройках — напоминания задач не ставятся.
    @ObservationIgnored var remindersEnabled = true

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let clock: any AppClock
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let reminders: any ReminderScheduling
    @ObservationIgnored private let logger = Logger(subsystem: "com.ahito.TickFlow", category: "Repository")

    init(
        context: ModelContext,
        clock: any AppClock = SystemClock(),
        calendar: Calendar = .current,
        reminders: any ReminderScheduling = SystemReminderScheduler()
    ) {
        self.context = context
        self.clock = clock
        self.calendar = calendar
        self.reminders = reminders
        reload()
    }

    // MARK: - Задачи

    func insert(_ tasks: [TaskItem]) {
        tasks.forEach(context.insert)
        commit()
    }

    @discardableResult
    func save(_ draft: TaskDraft, to task: TaskItem?) -> TaskItem {
        let item: TaskItem
        if let task {
            item = task
        } else {
            item = TaskItem(title: draft.title, sortOrder: nextSortOrder())
            context.insert(item)
        }
        apply(draft, to: item)
        commit()
        updateReminder(for: item)
        return item
    }

    @discardableResult
    func setCompleted(_ task: TaskItem, _ isCompleted: Bool) -> TaskItem? {
        task.setCompleted(isCompleted, at: clock.now)
        task.updatedAt = clock.now

        var next: TaskItem?
        if isCompleted, task.repeatRule != .never, let nextDraft = nextOccurrence(of: task) {
            // Выполненное вхождение остаётся в истории, правило переходит к следующему.
            let item = TaskItem(title: nextDraft.title, sortOrder: nextSortOrder())
            context.insert(item)
            apply(nextDraft, to: item)
            task.repeatRule = .never
            next = item
        }

        commit()
        updateReminder(for: task)
        if let next { updateReminder(for: next) }
        return next
    }

    func delete(_ task: TaskItem) {
        reminders.cancel(taskID: task.id)
        context.delete(task)
        commit()
    }

    @discardableResult
    func duplicate(_ task: TaskItem) -> TaskItem {
        var draft = TaskSnapshot(task).draft
        draft.title = task.title + L10n.Common.copySuffix
        draft.isCompleted = false
        draft.subtasks = draft.subtasks.map { SubtaskDraft(id: UUID(), title: $0.title, isCompleted: $0.isCompleted) }
        return save(draft, to: nil)
    }

    func restore(_ snapshot: TaskSnapshot) {
        let item: TaskItem
        if let existing = tasks.first(where: { $0.id == snapshot.id }) {
            item = existing
        } else {
            item = TaskItem(title: snapshot.draft.title)
            item.id = snapshot.id
            context.insert(item)
        }
        apply(snapshot.draft, to: item)
        item.completedAt = snapshot.completedAt
        item.createdAt = snapshot.createdAt
        item.sortOrder = snapshot.sortOrder
        relinkTimeEntries(snapshot.timeEntryIDs, to: item)
        commit()
        updateReminder(for: item)
    }

    func schedule(_ task: TaskItem, at start: Date) {
        task.dueDate = start
        task.hasTime = true
        task.endDay = nil
        task.updatedAt = clock.now
        commit()
        updateReminder(for: task)
    }

    func setDuration(_ task: TaskItem, minutes: Int) {
        task.durationMinutes = minutes
        task.updatedAt = clock.now
        commit()
    }

    func setDays(_ task: TaskItem, start: Date, end: Date) {
        let first = calendar.startOfDay(for: min(start, end))
        let last = calendar.startOfDay(for: max(start, end))
        task.dueDate = first
        task.hasTime = false
        task.endDay = first == last ? nil : last
        task.updatedAt = clock.now
        commit()
        updateReminder(for: task)
    }

    func moveToToday(_ task: TaskItem) {
        task.moveToToday(calendar: calendar, now: clock.now)
        task.updatedAt = clock.now
        commit()
        updateReminder(for: task)
    }

    func setTracking(_ task: TaskItem, _ override: Bool?) {
        task.trackingOverride = override
        task.updatedAt = clock.now
        commit()
    }

    func setEstimate(_ task: TaskItem, minutes: Int?) {
        task.estimateMinutes = minutes.map { max(0, $0) }
        task.updatedAt = clock.now
        commit()
    }

    func rescheduleReminders(enabled: Bool) {
        remindersEnabled = enabled
        tasks.forEach(updateReminder)
    }

    // MARK: - Списки

    func insert(_ lists: [TaskList]) {
        lists.forEach(context.insert)
        commit()
    }

    @discardableResult
    func save(_ draft: TaskListDraft, to list: TaskList?) -> TaskList {
        let item: TaskList
        if let list {
            item = list
            item.name = draft.name
            item.colorHex = draft.colorHex
            item.symbolName = draft.symbolName
            item.tracksTimeByDefault = draft.tracksTimeByDefault
        } else {
            item = TaskList(
                name: draft.name,
                colorHex: draft.colorHex,
                symbolName: draft.symbolName,
                sortOrder: (lists.map(\.sortOrder).max() ?? 0) + 1,
                tracksTimeByDefault: draft.tracksTimeByDefault
            )
            context.insert(item)
        }
        commit()
        return item
    }

    func delete(_ list: TaskList) {
        list.tasks.forEach { reminders.cancel(taskID: $0.id) }
        context.delete(list)
        commit()
    }

    // MARK: - Внутреннее

    private func apply(_ draft: TaskDraft, to item: TaskItem) {
        item.title = draft.title
        item.notes = draft.notes
        item.priority = draft.priority
        item.hasTime = draft.hasTime
        item.durationMinutes = draft.durationMinutes
        item.dueDate = draft.dueDate
        if let due = draft.dueDate, let end = draft.endDay, !calendar.isDate(due, inSameDayAs: end), end > due {
            item.endDay = calendar.startOfDay(for: end)
        } else {
            item.endDay = nil
        }
        item.reminder = draft.reminder
        item.repeatRule = draft.repeatRule
        item.list = draft.list
        item.trackingOverride = draft.trackingOverride
        item.estimateMinutes = draft.estimateMinutes.map { max(0, $0) }
        if item.isCompleted != draft.isCompleted {
            item.setCompleted(draft.isCompleted, at: clock.now)
        }
        item.updatedAt = clock.now
        syncSubtasks(draft.subtasks, on: item)
    }

    /// Черновик следующего вхождения повторяющейся задачи: та же длительность, подзадачи сброшены.
    private func nextOccurrence(of task: TaskItem) -> TaskDraft? {
        guard let due = task.dueDate, let nextDue = task.repeatRule.nextDate(after: due) else { return nil }
        var draft = TaskSnapshot(task).draft
        draft.dueDate = nextDue
        if let endDay = task.endDay {
            let span = endDay.timeIntervalSince(calendar.startOfDay(for: due))
            draft.endDay = calendar.startOfDay(for: nextDue).addingTimeInterval(span)
        }
        draft.isCompleted = false
        draft.subtasks = draft.subtasks.map { SubtaskDraft(id: UUID(), title: $0.title, isCompleted: false) }
        return draft
    }

    /// Удалённая задача теряет связь с записями (`nullify`). Восстановление возвращает её.
    private func relinkTimeEntries(_ ids: [UUID], to item: TaskItem) {
        guard !ids.isEmpty else { return }
        let entries = (try? context.fetch(FetchDescriptor<TimeEntry>(predicate: #Predicate { ids.contains($0.id) }))) ?? []
        for entry in entries where entry.task == nil {
            entry.task = item
        }
    }

    private func syncSubtasks(_ drafts: [SubtaskDraft], on item: TaskItem) {
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
                let subtask = Subtask(title: draft.title, isCompleted: draft.isCompleted, sortOrder: index)
                subtask.id = draft.id
                subtask.parent = item
                context.insert(subtask)
            }
        }
    }

    private func nextSortOrder() -> Int {
        (tasks.map(\.sortOrder).max() ?? 0) + 1
    }

    private func updateReminder(for task: TaskItem) {
        let fireDate = remindersEnabled ? task.reminderDate(now: clock.now) : nil
        reminders.reschedule(taskID: task.id, title: task.title, fireDate: fireDate)
    }

    private func commit() {
        do {
            try context.save()
        } catch {
            logger.error("Не удалось сохранить изменения: \(error.localizedDescription)")
        }
        reload()
    }

    private func reload() {
        do {
            tasks = try context.fetch(
                FetchDescriptor<TaskItem>(
                    sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
                )
            )
            lists = try context.fetch(FetchDescriptor<TaskList>(sortBy: [SortDescriptor(\.sortOrder)]))
        } catch {
            logger.error("Не удалось загрузить данные: \(error.localizedDescription)")
        }
    }
}
