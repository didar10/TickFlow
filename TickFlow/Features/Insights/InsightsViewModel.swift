import Foundation
import Observation

/// Экран «Аналитика»: задачи и привычки за период в сравнении с предыдущим.
@MainActor
@Observable
final class InsightsViewModel {
    enum Range: Hashable { case week, month, year }

    struct Kpi: Identifiable {
        var id: String { title }
        let title: String
        let value: String
        let delta: String
        let isGood: Bool

        /// Сравнивать не с чем: серый текст вместо зелёного или красного.
        var isNeutral: Bool { delta == "Нет данных для сравнения" || delta == "Как в прошлом периоде" }
    }

    struct Bar: Identifiable {
        let id: Int
        let label: String
        /// Подпись для текста вывода: "октябрь", "9 окт.".
        let title: String
        let created: Int
        let completed: Int
        let isBest: Bool
    }

    struct HabitRow: Identifiable {
        let id: UUID
        let name: String
        let detail: String
        let rate: Double
        let colorHex: String
    }

    struct Fact: Identifiable {
        var id: String { title }
        let title: String
        let value: String
    }

    /// Всё, что нужно экрану, посчитанное за один проход.
    struct Report {
        let period: String
        let kpis: [Kpi]
        let chartTitle: String
        let bars: [Bar]
        let maxBarValue: Int
        let note: String
        let consistency: String
        let habits: [HabitRow]
        let facts: [Fact]
    }

    var range: Range = .week

    @ObservationIgnored private let tasks: any TaskRepository
    @ObservationIgnored private let habits: any HabitRepository
    @ObservationIgnored private let settings: any SettingsRepository
    @ObservationIgnored private let navigator: AppNavigator

    init(tasks: any TaskRepository, habits: any HabitRepository, settings: any SettingsRepository, navigator: AppNavigator) {
        self.tasks = tasks
        self.habits = habits
        self.settings = settings
        self.navigator = navigator
    }

    var rangeOptions: [(value: Range, title: String)] {
        [(.week, "Неделя"), (.month, "Месяц"), (.year, "Год")]
    }

    func openSettings() { navigator.openSettings() }

    var hasData: Bool { !tasks.tasks.isEmpty || !habits.habits.isEmpty }
    var hasHabits: Bool { !habits.habits.isEmpty }

    var report: Report {
        let format = DisplayFormatter(settings: settings.settings)
        let calendar = format.calendar
        let today = format.today
        let interval = period(for: range, offset: 0, today: today, calendar: calendar)
        let previous = period(for: range, offset: -1, today: today, calendar: calendar)
        let all = tasks.tasks

        let current = TaskNumbers(tasks: all, interval: interval, today: today, calendar: calendar)
        let prior = TaskNumbers(tasks: all, interval: previous, today: today, calendar: calendar)

        let noData = "Нет данных для сравнения"
        let kpis: [Kpi] = [
            Kpi(title: "Выполнено", value: number(current.completed),
                delta: percentDelta(current.completed, prior.completed, emptyText: noData), isGood: current.completed >= prior.completed),
            Kpi(title: "Создано", value: number(current.created),
                delta: percentDelta(current.created, prior.created, emptyText: noData), isGood: current.created >= prior.created),
            Kpi(title: "Выполнение", value: "\(current.rate)%",
                delta: prior.hasDue ? pointsDelta(current.rate, prior.rate) : noData,
                isGood: !prior.hasDue || current.rate >= prior.rate),
            Kpi(title: "Просрочено", value: number(current.overdue),
                delta: percentDelta(current.overdue, prior.overdue), isGood: current.overdue <= prior.overdue),
        ]

        let bars = buckets(interval: interval, calendar: calendar, format: format, tasks: all)
        let peak = peakHours(in: interval, tasks: all, calendar: calendar, format: format)
        let bestWeekday = mostProductiveWeekday(in: interval, tasks: all, calendar: calendar)

        let skipKeeps = settings.settings.skippedDaysKeepStreak
        let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? today
        let prevLastDay = calendar.date(byAdding: .day, value: -1, to: previous.end) ?? today
        let text = HabitText(format: format)
        var rates: [Double] = [], prevRates: [Double] = []
        let habitRows: [HabitRow] = habits.habits.map { habit in
            let history = HabitHistory(habit: habit, calendar: calendar, today: today, skippedKeepStreak: skipKeeps)
            let now = history.completion(from: interval.start, to: lastDay)
            let before = history.completion(from: previous.start, to: prevLastDay)
            let rate = now.counted > 0 ? Double(now.done) / Double(now.counted) : 0
            if now.counted > 0 { rates.append(rate) }
            if before.counted > 0 { prevRates.append(Double(before.done) / Double(before.counted)) }
            return HabitRow(
                id: habit.id,
                name: habit.name,
                detail: "\(percent(rate)) · серия \(text.streak(history.stats))",
                rate: rate,
                colorHex: habit.colorHex
            )
        }
        .sorted { $0.rate > $1.rate }

        let elapsedEnd = min(interval.end, calendar.date(byAdding: .day, value: 1, to: today) ?? today)
        let days = max(1, calendar.dateComponents([.day], from: interval.start, to: elapsedEnd).day ?? 1)
        var facts: [Fact] = [
            Fact(title: "Самый продуктивный день", value: bestWeekday ?? "—"),
            Fact(title: "Пиковые часы", value: peak ?? "—"),
            Fact(title: "В среднем за день", value: average(Double(current.completed) / Double(days))),
        ]
        if !habits.habits.isEmpty {
            facts.insert(Fact(title: "Привычки, прошлый период", value: prevRates.isEmpty ? "—" : percent(mean(prevRates))), at: 0)
        }

        return Report(
            period: periodTitle,
            kpis: kpis,
            chartTitle: chartTitle,
            bars: bars,
            maxBarValue: max(1, bars.map { max($0.created, $0.completed) }.max() ?? 1),
            note: note(bars: bars, weekday: bestWeekday, peak: peak),
            consistency: rates.isEmpty ? "—" : percent(mean(rates)),
            habits: habitRows,
            facts: facts
        )
    }

    // MARK: - Периоды

    private var periodTitle: String {
        switch range {
        case .week: "Последние 7 дней"
        case .month: "Последние 30 дней"
        case .year: "Последние 12 месяцев"
        }
    }

    private var chartTitle: String {
        switch range {
        case .week: "По дням"
        case .month: "По неделям"
        case .year: "По месяцам"
        }
    }

    /// Интервал периода, заканчивающийся сегодня (`offset` 0) или перед ним (−1).
    private func period(for range: Range, offset: Int, today: Date, calendar: Calendar) -> DateInterval {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        switch range {
        case .week, .month:
            let length = range == .week ? 7 : 30
            let end = calendar.date(byAdding: .day, value: offset * length, to: tomorrow) ?? tomorrow
            let start = calendar.date(byAdding: .day, value: -length, to: end) ?? end
            return DateInterval(start: start, end: end)
        case .year:
            let thisMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
            let firstMonth = calendar.date(byAdding: .month, value: -11 + offset * 12, to: thisMonth) ?? thisMonth
            let end = offset == 0 ? tomorrow : (calendar.date(byAdding: .month, value: 12, to: firstMonth) ?? tomorrow)
            return DateInterval(start: firstMonth, end: end)
        }
    }

    private func buckets(interval: DateInterval, calendar: Calendar, format: DisplayFormatter, tasks: [TaskItem]) -> [Bar] {
        var ranges: [(label: String, title: String, interval: DateInterval)] = []
        switch range {
        case .week:
            let letters = calendar.veryShortStandaloneWeekdaySymbols
            for offset in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: interval.start),
                      let next = calendar.date(byAdding: .day, value: 1, to: day) else { continue }
                ranges.append((letters[calendar.component(.weekday, from: day) - 1], format.dayMonth(day),
                               DateInterval(start: day, end: next)))
            }
        case .month:
            var start = interval.start
            while start < interval.end {
                let next = min(calendar.date(byAdding: .day, value: 7, to: start) ?? interval.end, interval.end)
                ranges.append((format.dayMonth(start), format.dayMonth(start), DateInterval(start: start, end: next)))
                start = next
            }
            // Хвост короче трёх дней присоединяем к предыдущей неделе.
            if ranges.count > 1, let last = ranges.last, last.interval.duration < 3 * 86_400 {
                ranges.removeLast()
                let merged = DateInterval(start: ranges[ranges.count - 1].interval.start, end: last.interval.end)
                ranges[ranges.count - 1].interval = merged
            }
        case .year:
            for offset in 0..<12 {
                guard let month = calendar.date(byAdding: .month, value: offset, to: interval.start),
                      let next = calendar.date(byAdding: .month, value: 1, to: month) else { continue }
                let label = month.formatted(.dateTime.month(.narrow).locale(format.locale)).uppercased()
                let title = month.formatted(.dateTime.month(.wide).locale(format.locale))
                ranges.append((label, title, DateInterval(start: month, end: min(next, interval.end))))
            }
        }

        let counts = ranges.map { item in
            (created: tasks.filter { item.interval.start <= $0.createdAt && $0.createdAt < item.interval.end }.count,
             completed: completions(in: item.interval, tasks: tasks).count)
        }
        let best = counts.map(\.completed).max() ?? 0
        let bestIndex = best > 0 ? counts.firstIndex { $0.completed == best } : nil
        return ranges.indices.map { index in
            Bar(id: index, label: ranges[index].label, title: ranges[index].title, created: counts[index].created,
                completed: counts[index].completed, isBest: index == bestIndex)
        }
    }

    // MARK: - Выводы

    private func mostProductiveWeekday(in interval: DateInterval, tasks: [TaskItem], calendar: Calendar) -> String? {
        var counts: [Int: Int] = [:]
        for date in completions(in: interval, tasks: tasks) {
            counts[calendar.component(.weekday, from: date), default: 0] += 1
        }
        guard let best = counts.max(by: { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }) else { return nil }
        return calendar.standaloneWeekdaySymbols[best.key - 1].capitalizedFirst
    }

    /// Двухчасовое окно, в которое выполнено больше всего задач со временем.
    private func peakHours(in interval: DateInterval, tasks: [TaskItem], calendar: Calendar, format: DisplayFormatter) -> String? {
        var hours = Array(repeating: 0, count: 24)
        for task in tasks where task.hasTime {
            guard let done = task.completedAt, interval.start <= done, done < interval.end else { continue }
            hours[calendar.component(.hour, from: done)] += 1
        }
        let windows = (0..<23).map { (hour: $0, count: hours[$0] + hours[$0 + 1]) }
        guard let best = windows.max(by: { $0.count < $1.count }), best.count > 0 else { return nil }
        return format.shortTime(minute: best.hour * 60) + "–" + format.shortTime(minute: (best.hour + 2) * 60)
    }

    private func note(bars: [Bar], weekday: String?, peak: String?) -> String {
        guard let best = bars.first(where: \.isBest) else {
            return "Пока мало данных. Отмечайте задачи выполненными — здесь появятся выводы."
        }
        var parts: [String] = []
        switch range {
        case .week:
            if let weekday { parts.append("Самый продуктивный день — \(weekday.lowercased()): \(best.completed) \(Plural.tasks(best.completed)).") }
        case .month:
            parts.append("Лучшая неделя — с \(best.title): \(best.completed) \(Plural.tasks(best.completed)).")
        case .year:
            parts.append("Лучший месяц — \(best.title): \(best.completed) \(Plural.tasks(best.completed)).")
        }
        if let peak { parts.append("Чаще всего задачи выполняются в \(peak).") }
        return parts.joined(separator: " ")
    }

    private func completions(in interval: DateInterval, tasks: [TaskItem]) -> [Date] {
        tasks.compactMap(\.completedAt).filter { interval.start <= $0 && $0 < interval.end }
    }

    // MARK: - Числа

    private func number(_ value: Int) -> String {
        value.formatted(.number.locale(Locale(identifier: "ru_RU")))
    }

    private func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    private func average(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "ru_RU")))
    }

    private func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    /// `emptyText` — что показать, если в прошлом периоде было ноль.
    private func percentDelta(_ current: Int, _ previous: Int, emptyText: String? = nil) -> String {
        if current == previous { return "Как в прошлом периоде" }
        guard previous > 0 else { return emptyText ?? "+\(current) к прошлому периоду" }
        let change = Int((Double(current - previous) / Double(previous) * 100).rounded())
        return (change > 0 ? "+" : "") + "\(change)% к прошлому периоду"
    }

    private func pointsDelta(_ current: Int, _ previous: Int) -> String {
        let change = current - previous
        if change == 0 { return "Как в прошлом периоде" }
        return (change > 0 ? "+" : "") + "\(change) п.п. к прошлому"
    }
}

/// Счётчики задач за период.
private struct TaskNumbers {
    let completed: Int
    let created: Int
    /// Доля выполненных среди задач со сроком в периоде. Сегодняшние невыполненные не считаются:
    /// день ещё не закончился.
    let rate: Int
    let hasDue: Bool
    /// Задачи со сроком в периоде, которые так и не выполнены и уже прошли.
    let overdue: Int

    init(tasks: [TaskItem], interval: DateInterval, today: Date, calendar: Calendar) {
        func inside(_ date: Date?) -> Bool {
            guard let date else { return false }
            return interval.start <= date && date < interval.end
        }
        completed = tasks.filter { inside($0.completedAt) }.count
        created = tasks.filter { inside($0.createdAt) }.count

        let due = tasks.filter { task in
            guard let date = task.dueDate else { return false }
            let day = calendar.startOfDay(for: date)
            return inside(date) && (day < today || (day == today && task.isCompleted))
        }
        hasDue = !due.isEmpty
        rate = due.isEmpty ? 0 : Int((Double(due.filter(\.isCompleted).count) / Double(due.count) * 100).rounded())
        overdue = tasks.filter { task in
            guard let last = task.lastDay, !task.isCompleted else { return false }
            return inside(last) && last < today
        }.count
    }
}
