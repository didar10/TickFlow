import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var isCompleted: Bool = false
    var completedAt: Date?
    /// Дата выполнения. Если `hasTime == false`, хранится начало дня.
    var dueDate: Date?
    var hasTime: Bool = false
    var priorityRaw: Int = 0
    var sortOrder: Int = 0
    var createdAt: Date = Date.now

    var list: TaskList?

    @Relationship(deleteRule: .cascade, inverse: \Subtask.parent)
    var subtasks: [Subtask] = []

    init(
        title: String,
        notes: String = "",
        dueDate: Date? = nil,
        hasTime: Bool = false,
        priority: Priority = .none,
        list: TaskList? = nil,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.hasTime = hasTime
        self.priorityRaw = priority.rawValue
        self.list = list
        self.sortOrder = sortOrder
        self.createdAt = .now
    }

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue }
    }

    var sortedSubtasks: [Subtask] {
        subtasks.sorted { $0.sortOrder < $1.sortOrder }
    }

    var isOverdue: Bool {
        guard let dueDate, !isCompleted else { return false }
        return hasTime ? dueDate < .now : dueDate < Calendar.current.startOfDay(for: .now)
    }

    /// Момент срабатывания напоминания — только для задач со временем.
    var reminderDate: Date? {
        guard let dueDate, hasTime, !isCompleted, dueDate > .now else { return nil }
        return dueDate
    }

    func setCompleted(_ value: Bool) {
        isCompleted = value
        completedAt = value ? .now : nil
        if value {
            NotificationScheduler.cancel(taskID: id)
        } else {
            NotificationScheduler.reschedule(id: id, title: title, fireDate: reminderDate)
        }
    }
}
