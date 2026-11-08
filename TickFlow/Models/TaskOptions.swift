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
        case .none: L10n.Common.none
        case .atTime: L10n.Reminder.atTime
        case .tenMinutesBefore: L10n.Reminder.tenMinutes
        case .hourBefore: L10n.Reminder.oneHour
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
        case .never: L10n.Repeat.never
        case .daily: L10n.Common.everyDay
        case .weekdays: L10n.Common.weekdays
        case .weekly: L10n.Repeat.weekly
        case .monthly: L10n.Repeat.monthly
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
