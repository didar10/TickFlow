import Foundation

/// Поиск пересечений по времени между однодневными задачами со временем.
enum ConflictDetector {

    /// Первая незавершённая задача, которая пересекается с интервалом. `excluding` — сама задача.
    static func conflict(
        start: Date,
        end: Date,
        excluding id: UUID?,
        in tasks: [TaskItem],
        calendar: Calendar = .current
    ) -> TaskItem? {
        guard end > start, calendar.isDate(start, inSameDayAs: end.addingTimeInterval(-1)) else { return nil }
        return tasks.first { other in
            guard other.id != id, !other.isCompleted, other.hasTime, !other.isMultiDay,
                  let otherStart = other.dueDate, let otherEnd = other.endDate,
                  calendar.isDate(otherStart, inSameDayAs: start)
            else { return false }
            return otherStart < end && start < otherEnd
        }
    }

    static func conflict(for task: TaskItem, in tasks: [TaskItem]) -> TaskItem? {
        guard task.hasTime, !task.isMultiDay, !task.isCompleted,
              let start = task.dueDate, let end = task.endDate else { return nil }
        return conflict(start: start, end: end, excluding: task.id, in: tasks)
    }
}
