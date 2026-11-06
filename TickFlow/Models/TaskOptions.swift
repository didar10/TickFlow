import Foundation

/// Когда напомнить о задаче. Хранится как Int (`TaskItem.reminderRaw`).
enum ReminderOption: Int, CaseIterable, Identifiable, Codable {
    case none = 0
    case atTime = 1
    case tenMinutesBefore = 2
    case hourBefore = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: "Нет"
        case .atTime: "В момент начала"
        case .tenMinutesBefore: "За 10 минут"
        case .hourBefore: "За 1 час"
        }
    }

    /// Смещение от начала задачи. `nil` — напоминания нет.
    var offset: TimeInterval? {
        switch self {
        case .none: nil
        case .atTime: 0
        case .tenMinutesBefore: -10 * 60
        case .hourBefore: -60 * 60
        }
    }
}

/// Правило повтора задачи. Хранится как Int (`TaskItem.repeatRaw`).
enum RepeatRule: Int, CaseIterable, Identifiable, Codable {
    case never = 0
    case daily = 1
    case weekdays = 2
    case weekly = 3
    case monthly = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .never: "Никогда"
        case .daily: "Каждый день"
        case .weekdays: "По будням"
        case .weekly: "Каждую неделю"
        case .monthly: "Каждый месяц"
        }
    }

    /// Следующая дата после `date` или `nil`, если задача не повторяется.
    func nextDate(after date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .never:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case .weekdays:
            var next = date
            repeat {
                guard let candidate = calendar.date(byAdding: .day, value: 1, to: next) else { return nil }
                next = candidate
            } while calendar.isDateInWeekend(next)
            return next
        }
    }
}
