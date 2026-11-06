import Foundation
import Observation

/// Лист выбора даты: вкладки «Дата» и «Период», пресеты, месяц, время, напоминание, повтор.
@MainActor
@Observable
final class DateTimePickerViewModel: Identifiable {
    enum Tab: Hashable { case date, period }
    enum Section: Hashable { case time, reminder, repeatRule }

    enum PresetIcon: Equatable {
        case number(String)
        case sun
        case none
    }

    struct Preset: Identifiable {
        let id: String
        let title: String
        let icon: PresetIcon
        let isSelected: Bool
    }

    struct DayCell: Identifiable {
        let id: Int
        let date: Date?
        let label: String
        let isSelected: Bool
        let isToday: Bool
        let isPast: Bool
    }

    struct Option<Value: Hashable>: Identifiable {
        var id: Value { value }
        let value: Value
        let title: String
        let isSelected: Bool
    }

    var tab: Tab {
        didSet { if tab != oldValue { tabChanged() } }
    }
    private(set) var selection: DateSelection
    private(set) var displayedMonth: Date
    private(set) var expanded: Section?

    @ObservationIgnored private let format: DisplayFormatter
    @ObservationIgnored private let tasks: [TaskItem]
    @ObservationIgnored private let excludedID: UUID?
    @ObservationIgnored private let onApply: (DateSelection) -> Void
    /// Длительность, которую сохраняем при сдвиге начала во вкладке «Дата».
    @ObservationIgnored private var keptDuration: Int

    private var calendar: Calendar { format.calendar }

    init(
        selection: DateSelection,
        format: DisplayFormatter,
        tasks: [TaskItem],
        excluding id: UUID?,
        onApply: @escaping (DateSelection) -> Void
    ) {
        var initial = selection
        if initial.day == nil { initial.endDay = format.today }
        self.selection = initial
        self.format = format
        self.tasks = tasks
        excludedID = id
        self.onApply = onApply
        keptDuration = max(15, selection.durationMinutes)
        // Как в макете: лист всегда открывается на вкладке «Дата».
        tab = .date
        displayedMonth = (selection.day ?? format.today)
    }

    // MARK: - Состояние

    var hasDate: Bool { selection.day != nil }
    var isPeriod: Bool { tab == .period }
    var isInvalid: Bool { isPeriod && selection.isInvalid(calendar: calendar) }
    var canApply: Bool { !isInvalid }
    var isTimeExpanded: Bool { expanded == .time && selection.hasTime }
    var isReminderExpanded: Bool { expanded == .reminder }
    var isRepeatExpanded: Bool { expanded == .repeatRule }

    // MARK: - Вкладка «Дата»

    var presets: [Preset] {
        let today = format.today
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let nextMonday = nextWeekday(2, after: today)
        func isOn(_ date: Date?) -> Bool {
            guard let date else { return selection.day == nil }
            return selection.day.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        }
        return [
            Preset(id: "today", title: "Сегодня", icon: .number(String(calendar.component(.day, from: today))), isSelected: isOn(today)),
            Preset(id: "tomorrow", title: "Завтра", icon: .sun, isSelected: isOn(tomorrow)),
            Preset(id: "monday", title: "След. понедельник", icon: .number("Пн"), isSelected: isOn(nextMonday)),
            Preset(id: "none", title: "Без даты", icon: .none, isSelected: isOn(nil)),
        ]
    }

    var monthTitle: String { format.monthTitle(displayedMonth) }
    var weekdaySymbols: [String] { format.veryShortWeekdays }

    var cells: [DayCell] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let first = interval.start
        let lead = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let days = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let rows = Int((Double(lead + days) / 7).rounded(.up))
        let today = format.today
        return (0..<(rows * 7)).map { index in
            let dayNumber = index - lead + 1
            guard dayNumber >= 1, dayNumber <= days,
                  let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: first)
            else { return DayCell(id: index, date: nil, label: "", isSelected: false, isToday: false, isPast: false) }
            return DayCell(
                id: index,
                date: date,
                label: String(dayNumber),
                isSelected: selection.day.map { calendar.isDate($0, inSameDayAs: date) } ?? false,
                isToday: calendar.isDate(date, inSameDayAs: today),
                isPast: date < today
            )
        }
    }

    var hasTimeValue: Bool { selection.hasTime }

    var timeValue: String { selection.hasTime ? format.time(minute: selection.startMinute) : "Нет" }

    func selectPreset(_ id: String) {
        let today = format.today
        switch id {
        case "today": select(day: today)
        case "tomorrow": select(day: calendar.date(byAdding: .day, value: 1, to: today) ?? today)
        case "monday": select(day: nextWeekday(2, after: today))
        default:
            selection.day = nil
            expanded = nil
        }
    }

    func select(day: Date) {
        let start = calendar.startOfDay(for: day)
        let span = selection.day.map { calendar.dateComponents([.day], from: $0, to: selection.endDay).day ?? 0 } ?? 0
        selection.day = start
        selection.endDay = calendar.date(byAdding: .day, value: max(0, span), to: start) ?? start
        if tab == .date { selection.endDay = start }
        displayedMonth = start
    }

    func showPreviousMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
    }

    func showNextMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
    }

    func toggleTime() {
        if !selection.hasTime {
            selection.hasTime = true
            expanded = .time
        } else {
            expanded = expanded == .time ? nil : .time
        }
    }

    func clearTime() {
        selection.hasTime = false
        expanded = nil
    }

    // MARK: - Вкладка «Период»

    var startDayLabel: String { dayLabel(selection.day ?? format.today) }
    var endDayLabel: String { dayLabel(selection.endDay) }
    var startTimeLabel: String { format.time(minute: selection.startMinute) }
    var endTimeLabel: String { format.time(minute: selection.endMinute) }
    var isEndDayBeforeStart: Bool { selection.endDay < (selection.day ?? selection.endDay) }

    var durationLabel: String {
        guard !isInvalid else { return "" }
        if selection.isMultiDay(calendar: calendar), let day = selection.day {
            let days = (calendar.dateComponents([.day], from: day, to: selection.endDay).day ?? 0) + 1
            return "\(days) дн."
        }
        return format.duration(minutes: selection.durationMinutes)
    }

    func shiftStartTime(by delta: Int) {
        if tab == .period, !selection.isMultiDay(calendar: calendar) {
            let duration = max(15, selection.endMinute - selection.startMinute)
            let start = clamp(selection.startMinute + delta, 0, 1440 - duration)
            selection.startMinute = start
            selection.endMinute = start + duration
        } else {
            selection.startMinute = clamp(selection.startMinute + delta, 0, 1425)
            selection.hasTime = true
            if tab == .date {
                selection.endMinute = min(1440, selection.startMinute + keptDuration)
            }
        }
    }

    func shiftEndTime(by delta: Int) {
        selection.endMinute = clamp(selection.endMinute + delta, 15, 1440)
    }

    func shiftStartDay(by delta: Int) {
        guard let day = selection.day else { return }
        selection.day = calendar.date(byAdding: .day, value: delta, to: day) ?? day
        selection.endDay = calendar.date(byAdding: .day, value: delta, to: selection.endDay) ?? selection.endDay
    }

    func shiftEndDay(by delta: Int) {
        let next = calendar.date(byAdding: .day, value: delta, to: selection.endDay) ?? selection.endDay
        selection.endDay = max(next, selection.day ?? next)
    }

    // MARK: - Напоминание и повтор

    var reminderTitle: String { selection.reminder.title }
    var repeatTitle: String { selection.repeatRule.title }
    var hasReminder: Bool { selection.reminder != .none }
    var hasRepeat: Bool { selection.repeatRule != .never }

    var reminderOptions: [Option<ReminderOption>] {
        ReminderOption.allCases.map { Option(value: $0, title: $0.title, isSelected: $0 == selection.reminder) }
    }

    var repeatOptions: [Option<RepeatRule>] {
        RepeatRule.allCases.map { Option(value: $0, title: $0.title, isSelected: $0 == selection.repeatRule) }
    }

    func toggleReminder() { expanded = expanded == .reminder ? nil : .reminder }
    func toggleRepeat() { expanded = expanded == .repeatRule ? nil : .repeatRule }
    func setReminder(_ value: ReminderOption) { selection.reminder = value }
    func setRepeat(_ value: RepeatRule) { selection.repeatRule = value }

    // MARK: - Пересечение

    /// "Пересекается с «Обед» (13:30 – 14:30). Всё равно можно добавить."
    var conflictText: String? {
        guard selection.day != nil, selection.hasTime || isPeriod, !isInvalid,
              !selection.isMultiDay(calendar: calendar),
              let start = selection.startDate(calendar: calendar)
        else { return nil }
        let end = isPeriod
            ? selection.endDate(calendar: calendar) ?? start
            : start.addingTimeInterval(TimeInterval(keptDuration * 60))
        guard let other = ConflictDetector.conflict(start: start, end: end, excluding: excludedID, in: tasks, calendar: calendar),
              let otherStart = other.dueDate, let otherEnd = other.endDate
        else { return nil }
        return "Пересекается с «\(other.title)» (\(format.time(otherStart)) – \(format.time(otherEnd))). Всё равно можно добавить."
    }

    // MARK: - Готово

    func apply() {
        guard canApply else { return }
        var result = selection
        if result.day == nil {
            result.isPeriod = false
        } else if tab == .date {
            result.endDay = result.day ?? result.endDay
            result.isPeriod = false
            if result.hasTime { result.endMinute = min(1440, result.startMinute + keptDuration) }
        } else {
            result.hasTime = true
            result.isPeriod = true
        }
        onApply(result)
    }

    // MARK: - Внутреннее

    private func tabChanged() {
        guard tab == .period else { return }
        if selection.day == nil { selection.day = format.today }
        selection.hasTime = true
        selection.endDay = max(selection.endDay, selection.day ?? selection.endDay)
        if !selection.isMultiDay(calendar: calendar), selection.endMinute <= selection.startMinute {
            selection.endMinute = min(1440, selection.startMinute + 60)
        }
        expanded = nil
    }

    private func dayLabel(_ date: Date) -> String {
        let relative = format.relativeDay(date)
        let plain = format.weekdayAndDay(date)
        return relative == plain ? plain : relative + ", " + format.dayMonth(date)
    }

    private func nextWeekday(_ weekday: Int, after date: Date) -> Date {
        let current = calendar.component(.weekday, from: date)
        let delta = (weekday - current + 7) % 7
        return calendar.date(byAdding: .day, value: delta == 0 ? 7 : delta, to: date) ?? date
    }

    private func clamp(_ value: Int, _ low: Int, _ high: Int) -> Int {
        min(max(value, low), high)
    }
}
