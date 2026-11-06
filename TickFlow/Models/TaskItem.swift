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
    /// Длительность в минутах. Имеет смысл только при `hasTime == true`.
    var durationMinutes: Int = 60
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
        durationMinutes: Int = 60,
        priority: Priority = .none,
        list: TaskList? = nil,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.hasTime = hasTime
        self.durationMinutes = durationMinutes
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

    var endDate: Date? {
        guard let dueDate, hasTime else { return nil }
        return dueDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
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

    var completedSubtaskCount: Int {
        subtasks.filter(\.isCompleted).count
    }

    func setCompleted(_ value: Bool) {
        isCompleted = value
        completedAt = value ? .now : nil
    }

    /// Переносит на сегодня, сохраняя время, если оно указано.
    func moveToToday(calendar: Calendar = .current) {
        if hasTime, let dueDate {
            let components = calendar.dateComponents([.hour, .minute], from: dueDate)
            self.dueDate = calendar.date(
                bySettingHour: components.hour ?? 9,
                minute: components.minute ?? 0,
                second: 0,
                of: .now
            )
        } else {
            dueDate = calendar.startOfDay(for: .now)
        }
    }
}
