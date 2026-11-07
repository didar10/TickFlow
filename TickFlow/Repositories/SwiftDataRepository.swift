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
    @ObservationIgnored private let logger = Logger(subsystem: "com.ahito.TickFlow", category: "Repository")

    init(context: ModelContext) {
        self.context = context
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
        task.setCompleted(isCompleted)
        task.updatedAt = .now

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
        NotificationScheduler.cancel(taskID: task.id)
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
        commit()
        updateReminder(for: item)
    }

    func schedule(_ task: TaskItem, at start: Date) {
        task.dueDate = start
        task.hasTime = true
        task.endDay = nil
        task.updatedAt = .now
        commit()
        updateReminder(for: task)
    }

    func setDuration(_ task: TaskItem, minutes: Int) {
        task.durationMinutes = minutes
        task.updatedAt = .now
        commit()
    }

    func setDays(_ task: TaskItem, start: Date, end: Date) {
        let calendar = Calendar.current
        let first = calendar.startOfDay(for: min(start, end))
        let last = calendar.startOfDay(for: max(start, end))
        task.dueDate = first
        task.hasTime = false
        task.endDay = first == last ? nil : last
        task.updatedAt = .now
        commit()
        updateReminder(for: task)
    }

    func moveToToday(_ task: TaskItem) {
        task.moveToToday()
        task.updatedAt = .now
        commit()
        updateReminder(for: task)
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

    func save(_ draft: TaskListDraft, to list: TaskList?) {
        if let list {
            list.name = draft.name
            list.colorHex = draft.colorHex
            list.symbolName = draft.symbolName
        } else {
            context.insert(
                TaskList(
                    name: draft.name,
                    colorHex: draft.colorHex,
                    symbolName: draft.symbolName,
                    sortOrder: (lists.map(\.sortOrder).max() ?? 0) + 1
                )
            )
        }
        commit()
    }

    func delete(_ list: TaskList) {
        list.tasks.forEach { NotificationScheduler.cancel(taskID: $0.id) }
        context.delete(list)
        commit()
    }

    // MARK: - Внутреннее

    private func apply(_ draft: TaskDraft, to item: TaskItem) {
        let calendar = Calendar.current
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
        if item.isCompleted != draft.isCompleted {
            item.setCompleted(draft.isCompleted)
        }
        item.updatedAt = .now
        syncSubtasks(draft.subtasks, on: item)
    }

    /// Черновик следующего вхождения повторяющейся задачи: та же длительность, подзадачи сброшены.
    private func nextOccurrence(of task: TaskItem) -> TaskDraft? {
        guard let due = task.dueDate, let nextDue = task.repeatRule.nextDate(after: due) else { return nil }
        var draft = TaskSnapshot(task).draft
        draft.dueDate = nextDue
        if let endDay = task.endDay {
            let span = endDay.timeIntervalSince(Calendar.current.startOfDay(for: due))
            draft.endDay = Calendar.current.startOfDay(for: nextDue).addingTimeInterval(span)
        }
        draft.isCompleted = false
        draft.subtasks = draft.subtasks.map { SubtaskDraft(id: UUID(), title: $0.title, isCompleted: false) }
        return draft
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
        let fireDate = remindersEnabled ? task.reminderDate : nil
        NotificationScheduler.reschedule(id: task.id, title: task.title, fireDate: fireDate)
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
