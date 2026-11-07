import Foundation

/// Тексты дат и времени для экранов. Учитывает настройки (24 часа, первый день недели),
/// поэтому создаётся во ViewModel из текущих `AppSettings`.
struct DisplayFormatter {
    let calendar: Calendar
    let uses24HourTime: Bool
    let locale = DisplayFormatter.appLocale

    /// Язык, на котором показан интерфейс (из Localizable.xcstrings), — даты и числа пишутся на нём же.
    static let appLocale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "ru")

    init(settings: AppSettings, base: Calendar = .current) {
        var calendar = base
        calendar.firstWeekday = settings.firstWeekday
        calendar.locale = DisplayFormatter.appLocale
        self.calendar = calendar
        uses24HourTime = settings.uses24HourTime
    }

    var today: Date { calendar.startOfDay(for: .now) }

    // MARK: - Время

    /// Минуты от полуночи → "9:30" / "09:30" или "9:30 AM".
    func time(minute: Int) -> String {
        let h = (minute / 60) % 24, m = minute % 60
        if uses24HourTime { return String(format: "%02d:%02d", h, m) }
        return String(format: "%d:%02d %@", h % 12 == 0 ? 12 : h % 12, m, h < 12 ? "AM" : "PM")
    }

    func time(_ date: Date) -> String {
        time(minute: minute(of: date))
    }

    /// Короткое время для сетки календаря без AM/PM.
    func shortTime(minute: Int) -> String {
        let h = (minute / 60) % 24, m = minute % 60
        return uses24HourTime ? String(format: "%02d:%02d", h, m) : String(format: "%d:%02d", h % 12 == 0 ? 12 : h % 12, m)
    }

    func hourLabel(_ hour: Int) -> String {
        uses24HourTime ? String(format: "%02d:00", hour) : "\(hour % 12 == 0 ? 12 : hour % 12) \(hour < 12 ? "AM" : "PM")"
    }

    func minute(of date: Date) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    func duration(minutes: Int) -> String {
        DateFormatting.duration(minutes: minutes)
    }

    // MARK: - Дни

    /// "Сегодня", "Завтра", "Вчера" или "Пт, 7 нояб.".
    func relativeDay(_ date: Date) -> String {
        if calendar.isDateInToday(date) { return L10n.Common.today }
        if calendar.isDateInTomorrow(date) { return L10n.Common.tomorrow }
        if calendar.isDateInYesterday(date) { return L10n.Common.yesterday }
        return weekdayAndDay(date)
    }

    /// "Пт, 7 нояб."
    func weekdayAndDay(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(locale)).capitalizedFirst
    }

    /// "7 нояб."
    func dayMonth(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(locale))
    }

    /// "Пятница, 7 ноября"
    func fullDay(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale)).capitalizedFirst
    }

    /// "7 – 9 нояб." или "30 нояб. – 2 дек."
    func shortRange(_ start: Date, _ end: Date) -> String {
        if calendar.isDate(start, equalTo: end, toGranularity: .month) {
            return "\(calendar.component(.day, from: start)) – \(dayMonth(end))"
        }
        return dayMonth(start) + " – " + dayMonth(end)
    }

    func monthName(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).locale(locale)).capitalizedFirst
    }

    /// "Ноябрь" или "Ноябрь 2027", если год не текущий.
    func monthTitle(_ date: Date) -> String {
        calendar.isDate(date, equalTo: .now, toGranularity: .year)
            ? monthName(date)
            : monthName(date) + " " + String(calendar.component(.year, from: date))
    }

    /// Однобуквенные дни недели в порядке настроек: "П", "В", "С"…
    var veryShortWeekdays: [String] {
        rotate(calendar.veryShortStandaloneWeekdaySymbols)
    }

    var shortWeekdays: [String] {
        rotate(calendar.shortStandaloneWeekdaySymbols).map(\.capitalizedFirst)
    }

    private func rotate(_ symbols: [String]) -> [String] {
        let shift = calendar.firstWeekday - 1
        guard shift > 0, shift < symbols.count else { return symbols }
        return Array(symbols[shift...] + symbols[..<shift])
    }

    // MARK: - Задачи

    /// Подпись срока задачи: "Сегодня, 9:30", "7 – 9 нояб.", "Без даты".
    func dueLabel(for task: TaskItem) -> String {
        guard let due = task.dueDate else { return L10n.Common.noDate }
        if task.isMultiDay, let last = task.lastDay { return shortRange(due, last) }
        return task.hasTime ? relativeDay(due) + ", " + time(due) : relativeDay(due)
    }
}

extension String {
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}
