import Foundation

/// Календари с фиксированными зоной, локалью и первым днём недели:
/// результат тестов не зависит от настроек машины, на которой они идут.
enum TestCalendar {
    /// Без перехода на летнее время.
    static let moscow = make(timeZone: "Europe/Moscow")
    /// С переходом на летнее время: 29.03.2026 02:00 → 03:00, 25.10.2026 03:00 → 02:00.
    static let berlin = make(timeZone: "Europe/Berlin")

    /// - Parameter firstWeekday: 1 — воскресенье, 2 — понедельник (как `Calendar.firstWeekday`).
    static func make(timeZone: String, firstWeekday: Int = 2, locale: String = "ru_RU") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        calendar.locale = Locale(identifier: locale)
        calendar.firstWeekday = firstWeekday
        return calendar
    }
}

/// Короткая фабрика дат: `date("2026-11-08")` или `date("2026-11-08 09:30")`.
func date(_ string: String, calendar: Calendar = TestCalendar.moscow) -> Date {
    let parts = string.split(separator: " ")
    let day = parts[0].split(separator: "-").compactMap { Int($0) }
    let time = parts.count > 1 ? parts[1].split(separator: ":").compactMap { Int($0) } : [0, 0]
    precondition(day.count == 3 && time.count == 2, "Ожидается формат yyyy-MM-dd[ HH:mm]: \(string)")

    let components = DateComponents(year: day[0], month: day[1], day: day[2], hour: time[0], minute: time[1])
    guard let result = calendar.date(from: components) else {
        preconditionFailure("Некорректная дата: \(string)")
    }
    return result
}
