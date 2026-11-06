import Foundation

/// Срок задачи в редакторе: день, время, период, напоминание и повтор.
/// Значение, а не модель: пикер меняет копию и возвращает её только по «Готово».
struct DateSelection: Equatable {
    /// Начало дня. `nil` — без даты.
    var day: Date?
    /// Последний день. Совпадает с `day`, если задача однодневная.
    var endDay: Date
    var hasTime: Bool
    /// Минуты от полуночи `day`.
    var startMinute: Int
    /// Минуты от полуночи `endDay`. 1440 — полночь следующего дня.
    var endMinute: Int
    var reminder: ReminderOption
    var repeatRule: RepeatRule
    /// Выбран режим «Период»: в подписи показывается и конец.
    var isPeriod: Bool

    func isMultiDay(calendar: Calendar = .current) -> Bool {
        guard let day else { return false }
        return !calendar.isDate(day, inSameDayAs: endDay)
    }

    func startDate(calendar: Calendar = .current) -> Date? {
        guard let day else { return nil }
        return calendar.date(byAdding: .minute, value: startMinute, to: day)
    }

    func endDate(calendar: Calendar = .current) -> Date? {
        calendar.date(byAdding: .minute, value: endMinute, to: endDay)
    }

    /// Конец раньше начала или равен ему.
    func isInvalid(calendar: Calendar = .current) -> Bool {
        guard let day else { return false }
        if endDay < day { return true }
        guard hasTime, let start = startDate(calendar: calendar), let end = endDate(calendar: calendar) else { return false }
        return end <= start
    }

    var durationMinutes: Int {
        guard let start = startDate(), let end = endDate() else { return 60 }
        return max(15, Int(end.timeIntervalSince(start) / 60))
    }
}
