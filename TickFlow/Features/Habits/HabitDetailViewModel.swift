import Foundation
import Observation

/// Экран привычки: серии, месяц истории, недельный тренд и пропуск дня.
@MainActor
@Observable
final class HabitDetailViewModel {
    struct Stat: Identifiable {
        var id: String { title }
        let title: String
        let value: String
        let detail: String
    }

    struct DayCell: Identifiable {
        let id: Int
        /// `nil` — пустая ячейка перед первым числом.
        let day: Date?
        let number: String
        let state: HabitDayState
        let isSelected: Bool
    }

    struct TrendBar: Identifiable {
        let id: Int
        let value: String
        let label: String
        let fraction: Double
        let isCurrent: Bool
    }

    struct InfoRow: Identifiable {
        var id: String { title }
        let title: String
        let value: String
    }

    var editorRequest: HabitEditorRequest?
    /// Смещение показанного месяца от текущего. Вперёд — не дальше следующего.
    private(set) var monthOffset = 0
    private(set) var selectedDay: Date?

    @ObservationIgnored private let id: UUID
    @ObservationIgnored private let repository: any HabitRepository
    @ObservationIgnored private let settings: any SettingsRepository
    @ObservationIgnored private let toasts: ToastCenter

    init(id: UUID, habits: any HabitRepository, settings: any SettingsRepository, toasts: ToastCenter) {
        self.id = id
        repository = habits
        self.settings = settings
        self.toasts = toasts
    }

    private var habit: Habit? { repository.habits.first { $0.id == id } }
    private var format: DisplayFormatter { DisplayFormatter(settings: settings.settings) }
    private var text: HabitText { HabitText(format: format) }

    private var history: HabitHistory? {
        habit.map {
            HabitHistory(habit: $0, calendar: format.calendar, today: format.today,
                         skippedKeepStreak: settings.settings.skippedDaysKeepStreak)
        }
    }

    /// Привычку удалили: экран нужно закрыть.
    var isMissing: Bool { habit == nil }

    // MARK: - Шапка

    var name: String { habit?.name ?? "" }
    var symbolName: String { habit?.symbolName ?? "book" }
    var colorHex: String { habit?.colorHex ?? AppColors.fallbackList }

    var meta: String {
        guard let habit else { return "" }
        return text.schedule(of: habit) + " · " + text.target(of: habit)
    }

    var stats: [Stat] {
        guard let history else { return [] }
        let stats = history.stats
        let text = text
        let toBest = stats.best - stats.current
        return [
            Stat(title: "Текущая серия", value: text.streak(stats),
                 detail: stats.current > 0 && toBest <= 0 ? "Личный рекорд" : "Ещё \(text.streak(stats, count: toBest)) до рекорда"),
            Stat(title: "Лучшая серия", value: text.streak(stats, count: stats.best), detail: "За всё время"),
            Stat(title: "Выполнение", value: "\(stats.rate)%", detail: stats.isWeekly ? "За 4 недели" : "За 30 дней"),
            Stat(title: "Всего", value: String(stats.total), detail: "Раз выполнено"),
        ]
    }

    // MARK: - Месяц

    private var month: Date {
        let calendar = format.calendar
        let start = calendar.dateInterval(of: .month, for: format.today)?.start ?? format.today
        return calendar.date(byAdding: .month, value: monthOffset, to: start) ?? start
    }

    var monthTitle: String {
        format.monthName(month) + " " + String(format.calendar.component(.year, from: month))
    }

    var canShowNextMonth: Bool { monthOffset < 1 }
    var weekdaySymbols: [String] { format.veryShortWeekdays }

    var cells: [DayCell] {
        guard let history else { return [] }
        let calendar = format.calendar
        let first = month
        let lead = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: first)?.count ?? 30

        let empty = (0..<lead).map { DayCell(id: -$0 - 1, day: nil, number: "", state: .rest, isSelected: false) }
        let days: [DayCell] = (0..<count).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: first) else { return nil }
            return DayCell(
                id: offset,
                day: day,
                number: String(offset + 1),
                state: history.state(on: day),
                isSelected: selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false
            )
        }
        return empty + days
    }

    var selectedInfo: String? {
        guard let selectedDay, let history else { return nil }
        var info = format.weekdayAndDay(selectedDay) + " · " + history.state(on: selectedDay).label
        if let habit, habit.kind != .check, history.value(on: selectedDay) > 0, !history.isDone(on: selectedDay) {
            info += " · \(text.value(history.value(on: selectedDay))) из \(text.value(habit.target)) \(text.unit(of: habit))"
        }
        return info
    }

    func showPreviousMonth() {
        monthOffset -= 1
        selectedDay = nil
    }

    func showNextMonth() {
        guard canShowNextMonth else { return }
        monthOffset += 1
        selectedDay = nil
    }

    func select(_ day: Date?) {
        guard let day else { return }
        selectedDay = format.calendar.isDate(day, inSameDayAs: selectedDay ?? .distantPast) ? nil : day
    }

    // MARK: - Тренд

    var trend: [TrendBar] {
        guard let history else { return [] }
        let calendar = format.calendar
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: format.today)?.start ?? format.today
        return (0..<8).reversed().map { weeksAgo in
            let start = calendar.date(byAdding: .day, value: -7 * weeksAgo, to: thisWeek) ?? thisWeek
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
            let result = history.completion(from: start, to: end)
            let fraction = result.counted > 0 ? Double(result.done) / Double(result.counted) : 0
            return TrendBar(
                id: weeksAgo,
                value: "\(Int((fraction * 100).rounded()))%",
                label: weeksAgo == 0 ? "Сейчас" : "−\(weeksAgo) н",
                fraction: fraction,
                isCurrent: weeksAgo == 0
            )
        }
    }

    // MARK: - Детали

    var infoRows: [InfoRow] {
        guard let habit else { return [] }
        return [
            InfoRow(title: "Цель", value: text.target(of: habit)),
            InfoRow(title: "Частота", value: text.schedule(of: habit)),
            InfoRow(title: "Напоминание", value: reminderText(habit)),
            InfoRow(title: "Дни отдыха", value: settings.settings.allowsRestDays ? "Разрешены" : "Выкл."),
        ]
    }

    var footnote: String {
        settings.settings.skippedDaysKeepStreak
            ? "Пропуски и дни отдыха не прерывают серию. Будущие дни не учитываются."
            : "Дни отдыха не прерывают серию. Будущие дни не учитываются."
    }

    var skipTitle: String {
        guard let history else { return "" }
        if history.isDone(on: format.today) { return "Отметить как невыполненное" }
        if history.isSkipped(on: format.today) { return "Отменить пропуск" }
        return "Пропустить сегодня"
    }

    // MARK: - Действия

    func skipOrReset() {
        guard let habit, let history else { return }
        let today = format.today
        if history.isDone(on: today) {
            let previous = history.value(on: today)
            repository.setValue(0, for: habit, on: today)
            toasts.show("Отметка снята") { [repository] in repository.setValue(previous, for: habit, on: today) }
        } else if history.isSkipped(on: today) {
            repository.setSkipped(false, for: habit, on: today)
        } else {
            let previous = history.value(on: today)
            repository.setSkipped(true, for: habit, on: today)
            let message = settings.settings.skippedDaysKeepStreak ? "Сегодня пропущено. Серия сохранена" : "Сегодня пропущено"
            toasts.show(message) { [repository] in
                repository.setSkipped(false, for: habit, on: today)
                if previous > 0 { repository.setValue(previous, for: habit, on: today) }
            }
        }
    }

    func edit() {
        guard let habit else { return }
        editorRequest = .edit(habit)
    }

    private func reminderText(_ habit: Habit) -> String {
        guard habit.reminderEnabled, settings.settings.habitRemindersEnabled else { return "Выкл." }
        return format.time(minute: habit.reminderMinute)
    }
}
