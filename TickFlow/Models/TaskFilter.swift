import Foundation

/// Вариант подборки задач: смарт-список или пользовательский список.
enum TaskFilter: Hashable, Codable {
    case today
    case upcoming
    case all
    case completed
    case list(UUID)

    var isSmart: Bool {
        if case .list = self { return false }
        return true
    }

    var defaultTitle: String {
        switch self {
        case .today: "Сегодня"
        case .upcoming: "Ближайшие 7 дней"
        case .all: "Все задачи"
        case .completed: "Завершённые"
        case .list: "Список"
        }
    }

    var symbolName: String {
        switch self {
        case .today: "star"
        case .upcoming: "calendar"
        case .all: "tray.full"
        case .completed: "checkmark.circle"
        case .list: "list.bullet"
        }
    }

    /// Дата, которая подставляется в новую задачу, созданную внутри этой подборки.
    var defaultDueDate: Date? {
        switch self {
        case .today: Calendar.current.startOfDay(for: .now)
        default: nil
        }
    }

    func matches(_ task: TaskItem, calendar: Calendar = .current) -> Bool {
        switch self {
        case .today:
            guard !task.isCompleted, let due = task.dueDate else { return false }
            return calendar.startOfDay(for: due) <= calendar.startOfDay(for: .now)
        case .upcoming:
            guard !task.isCompleted, let due = task.dueDate else { return false }
            let start = calendar.startOfDay(for: .now)
            guard let end = calendar.date(byAdding: .day, value: 7, to: start) else { return false }
            return due < end
        case .all:
            return !task.isCompleted
        case .completed:
            return task.isCompleted
        case .list(let id):
            return task.list?.id == id && !task.isCompleted
        }
    }
}
