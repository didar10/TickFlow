import Foundation

/// Состояние привычки в конкретный день.
enum HabitDayState: Equatable {
    case done
    /// Пропуск по желанию: серия не прерывается (если так в настройках).
    case skipped
    case missed
    /// День не запланирован.
    case rest
    /// Будущий запланированный день.
    case planned
    /// Сегодня, запланировано, ещё не выполнено.
    case today
    /// До начала привычки.
    case notStarted

    var label: String {
        switch self {
        case .done: L10n.Common.completed
        case .skipped: L10n.HabitState.skipped
        case .missed: L10n.HabitState.missed
        case .rest: L10n.HabitState.rest
        case .planned: L10n.Common.planned
        case .today: L10n.HabitState.today
        case .notStarted: L10n.HabitState.notStarted
        }
    }
}

struct HabitStats {
    let current: Int
    let best: Int
    /// Процент выполнения за 30 дней.
    let rate: Int
    let total: Int
    /// Серия недельной цели считается в неделях.
    let isWeekly: Bool
}

/// История одной привычки: состояния дней, серии и процент выполнения.
/// Чистая логика без базы: принимает модель и считает по её отметкам.
struct HabitHistory {
    let habit: Habit
    let calendar: Calendar
    let today: Date
    let skippedKeepStreak: Bool

    private let logs: [Date: HabitLog]
    private let start: Date

    init(habit: Habit, calendar: Calendar, today: Date, skippedKeepStreak: Bool) {
        self.habit = habit
        self.calendar = calendar
        self.today = calendar.startOfDay(for: today)
        self.skippedKeepStreak = skippedKeepStreak
        var logs: [Date: HabitLog] = [:]
        for log in habit.logs {
            logs[calendar.startOfDay(for: log.day)] = log
        }
        self.logs = logs
        start = calendar.startOfDay(for: habit.startDate)
    }

    func value(on day: Date) -> Double {
        logs[calendar.startOfDay(for: day)]?.value ?? 0
    }

    func isDone(on day: Date) -> Bool {
        value(on: day) >= habit.target
    }

    func isSkipped(on day: Date) -> Bool {
        logs[calendar.startOfDay(for: day)]?.isSkipped ?? false
    }

    func state(on date: Date) -> HabitDayState {
        let day = calendar.startOfDay(for: date)
        if isDone(on: day) { return .done }
        if isSkipped(on: day) { return .skipped }
        if day < start { return .notStarted }
        let scheduled = habit.frequency != .weeklyGoal && habit.isScheduled(on: day, calendar: calendar)
        if day == today { return habit.isScheduled(on: day, calendar: calendar) ? .today : .rest }
        if day > today { return scheduled ? .planned : .rest }
        return scheduled ? .missed : .rest
    }

    var stats: HabitStats {
        habit.frequency == .weeklyGoal ? weeklyStats : dailyStats
    }

    /// Доля выполненных среди учитываемых дней (выполнено + не выполнено) в интервале.
    func completion(from first: Date, to last: Date) -> (done: Int, counted: Int) {
        var done = 0, counted = 0
        var day = calendar.startOfDay(for: first)
        let end = min(calendar.startOfDay(for: last), today)
        while day <= end {
            switch state(on: day) {
            case .done: done += 1; counted += 1
            case .missed: counted += 1
            default: break
            }
            day = adding(1, to: day)
        }
        return (done, counted)
    }

    // MARK: - Внутреннее

    private var dailyStats: HabitStats {
        // Текущая: назад от сегодня. Невыполненное сегодня серию ещё не прерывает.
        var current = 0
        var day = today
        loop: while day >= start {
            switch state(on: day) {
            case .done: current += 1
            case .today, .rest: break
            case .skipped: if !skippedKeepStreak { break loop }
            case .missed, .notStarted, .planned: break loop
            }
            day = adding(-1, to: day)
        }

        var best = 0, run = 0
        day = start
        while day <= today {
            switch state(on: day) {
            case .done: run += 1; best = max(best, run)
            case .missed: run = 0
            case .skipped: if !skippedKeepStreak { run = 0 }
            default: break
            }
            day = adding(1, to: day)
        }

        let month = completion(from: adding(-29, to: today), to: today)
        let rate = month.counted > 0 ? Int((Double(month.done) / Double(month.counted) * 100).rounded()) : 0
        return HabitStats(current: current, best: max(best, current), rate: rate, total: totalDone, isWeekly: false)
    }

    /// Недельная цель: серия — подряд идущие недели, где цель достигнута.
    /// Текущая неделя засчитывается, только когда цель уже выполнена.
    private var weeklyStats: HabitStats {
        let goal = max(1, habit.timesPerWeek)
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start else {
            return HabitStats(current: 0, best: 0, rate: 0, total: totalDone, isWeekly: true)
        }

        func doneCount(weekStart: Date) -> Int {
            (0..<7).filter { isDone(on: adding($0, to: weekStart)) }.count
        }

        var current = 0
        var week = thisWeek
        if doneCount(weekStart: week) >= goal { current = 1 }
        week = adding(-7, to: week)
        while adding(6, to: week) >= start, doneCount(weekStart: week) >= goal {
            current += 1
            week = adding(-7, to: week)
        }

        var best = 0, run = 0
        week = calendar.dateInterval(of: .weekOfYear, for: start)?.start ?? start
        while week <= thisWeek {
            if doneCount(weekStart: week) >= goal {
                run += 1
                best = max(best, run)
            } else if week < thisWeek {
                run = 0
            }
            week = adding(7, to: week)
        }

        let done = (0..<28).filter { isDone(on: adding(-$0, to: today)) }.count
        let rate = min(100, Int((Double(done) / Double(goal * 4) * 100).rounded()))
        return HabitStats(current: current, best: max(best, current), rate: rate, total: totalDone, isWeekly: true)
    }

    private var totalDone: Int {
        logs.values.filter { $0.value >= habit.target }.count
    }

    private func adding(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }
}

/// Тексты привычек, общие для списка, деталей и аналитики.
struct HabitText {
    let format: DisplayFormatter

    func value(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).locale(format.locale))
    }

    func unit(of habit: Habit) -> String {
        habit.kind == .duration ? L10n.Format.minutesUnit : habit.unit
    }

    /// "Каждый день", "По будням", "Пн, Ср, Пт", "3 раза в неделю".
    func schedule(of habit: Habit) -> String {
        switch habit.frequency {
        case .daily:
            return L10n.Common.everyDay
        case .weeklyGoal:
            return L10n.Habits.timesPerWeek(L10n.Plural.times(habit.timesPerWeek))
        case .specificDays:
            let days = Set(habit.weekdays)
            if days == [2, 3, 4, 5, 6] { return L10n.Common.weekdays }
            if days.count == 7 { return L10n.Common.everyDay }
            let symbols = format.calendar.shortStandaloneWeekdaySymbols.map(\.capitalizedFirst)
            return weekdayOrder.filter(days.contains).map { symbols[$0 - 1] }.joined(separator: ", ")
        }
    }

    /// "Отметить выполнение", "20 мин в день".
    func target(of habit: Habit) -> String {
        habit.kind == .check ? L10n.Habits.markCompletion : L10n.Habits.perDay(value(habit.target), unit(of: habit))
    }

    func streak(_ stats: HabitStats, count: Int? = nil) -> String {
        let n = count ?? stats.current
        return stats.isWeekly ? L10n.Format.weeksShort(n) : L10n.Plural.days(n)
    }

    /// Дни недели (1 — вс … 7 — сб) в порядке первого дня недели из настроек.
    var weekdayOrder: [Int] {
        (0..<7).map { (format.calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }
}
