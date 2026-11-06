import Foundation
import Observation
import OSLog
import SwiftData

/// Единственное место, которое знает про SwiftData и напоминания.
/// Один класс на оба протокола: удаление списка каскадно меняет и задачи,
/// поэтому кэши должны обновляться вместе.
@MainActor
@Observable
final class SwiftDataRepository: TaskRepository, TaskListRepository {
    private(set) var tasks: [TaskItem] = []
    private(set) var lists: [TaskList] = []

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

    func save(_ draft: TaskDraft, to task: TaskItem?) {
        let item: TaskItem
        if let task {
            item = task
        } else {
            item = TaskItem(title: draft.title)
            context.insert(item)
        }

        item.title = draft.title
        item.notes = draft.notes
        item.priority = draft.priority
        item.hasTime = draft.hasTime
        item.durationMinutes = draft.durationMinutes
        item.dueDate = draft.dueDate
        item.list = draft.list
        syncSubtasks(draft.subtasks, on: item)

        commit()
        updateReminder(for: item)
    }

    func setCompleted(_ task: TaskItem, _ isCompleted: Bool) {
        task.setCompleted(isCompleted)
        commit()
        updateReminder(for: task)
    }

    func delete(_ task: TaskItem) {
        NotificationScheduler.cancel(taskID: task.id)
        context.delete(task)
        commit()
    }

    func schedule(_ task: TaskItem, at start: Date) {
        task.dueDate = start
        task.hasTime = true
        commit()
        updateReminder(for: task)
    }

    func setDuration(_ task: TaskItem, minutes: Int) {
        task.durationMinutes = minutes
        commit()
    }

    func moveToToday(_ task: TaskItem) {
        task.moveToToday()
        commit()
        updateReminder(for: task)
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
                subtask.parent = item
                context.insert(subtask)
            }
        }
    }

    private func updateReminder(for task: TaskItem) {
        NotificationScheduler.reschedule(id: task.id, title: task.title, fireDate: task.reminderDate)
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
