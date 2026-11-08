import Foundation
import Observation

/// Что открыть в редакторе привычки.
struct HabitEditorRequest: Identifiable {
    let id = UUID()
    let habit: Habit?
    let suggestion: HabitSuggestion?

    static func new(_ suggestion: HabitSuggestion? = nil) -> HabitEditorRequest {
        HabitEditorRequest(habit: nil, suggestion: suggestion)
    }

    static func edit(_ habit: Habit) -> HabitEditorRequest {
        HabitEditorRequest(habit: habit, suggestion: nil)
    }
}

/// Готовая привычка для быстрого старта.
struct HabitSuggestion: Identifiable {
    var id: String { name }
    let name: String
    let symbolName: String
    let colorHex: String
    let kind: HabitKind
    let target: Double
    let unit: String

    static let all: [HabitSuggestion] = [
        HabitSuggestion(name: L10n.Habits.suggestionReading, symbolName: "book", colorHex: "#5B5BD6", kind: .duration, target: 20, unit: L10n.Format.minutesUnit),
        HabitSuggestion(name: L10n.Habits.suggestionWater, symbolName: "drop", colorHex: "#2A9792", kind: .amount, target: 2, unit: L10n.Habits.unitLiters),
        HabitSuggestion(name: L10n.Habits.suggestionWorkout, symbolName: "dumbbell", colorHex: "#CF8526", kind: .check, target: 1, unit: ""),
        HabitSuggestion(name: L10n.Habits.suggestionMeditation, symbolName: "leaf", colorHex: "#399E62", kind: .duration, target: 10, unit: L10n.Format.minutesUnit),
        HabitSuggestion(name: L10n.Habits.suggestionLearn, symbolName: "lightbulb", colorHex: "#BE5A96", kind: .check, target: 1, unit: ""),
    ]
}

/// Экран «Привычки»: сводка дня, неделя и отметка привычек на сегодня.
@MainActor
@Observable
final class HabitsViewModel {
    struct Row: Identifiable {
        let id: UUID
        let name: String
        let symbolName: String
        let colorHex: String
        let subtitle: String
        let isMeasurable: Bool
        let progress: Double
        let streak: String
        let isDone: Bool
    }

    struct WeekBar: Identifiable {
        let id: Date
        let letter: String
        /// `nil` — будущий день.
        let fraction: Double?
        let isToday: Bool
    }

    var path: [UUID] = []
    var editorRequest: HabitEditorRequest?

    @ObservationIgnored private let repository: any HabitRepository
    @ObservationIgnored private let settings: any SettingsRepository
    @ObservationIgnored private let toasts: ToastCenter
    @ObservationIgnored private let navigator: AppNavigator
    @ObservationIgnored private let clock: any AppClock

    init(
        habits: any HabitRepository,
        settings: any SettingsRepository,
        toasts: ToastCenter,
        navigator: AppNavigator,
        clock: any AppClock = SystemClock()
    ) {
        self.clock = clock
        repository = habits
        self.settings = settings
        self.toasts = toasts
        self.navigator = navigator
    }

    private var format: DisplayFormatter { DisplayFormatter(settings: settings.settings, clock: clock) }
    private var text: HabitText { HabitText(format: format) }

    private func history(_ habit: Habit) -> HabitHistory {
        HabitHistory(habit: habit, calendar: format.calendar, today: format.today,
                     skippedKeepStreak: settings.settings.skippedDaysKeepStreak)
    }

    // MARK: - Шапка и сводка

    var dateLabel: String { format.fullDay(format.today) }
    var hasHabits: Bool { !repository.habits.isEmpty }
    var suggestions: [HabitSuggestion] { HabitSuggestion.all }

    /// Привычки, которые учитываются сегодня: запланированные или уже выполненные.
    private var todayCounted: [(Habit, HabitHistory)] {
        let today = format.today
        return repository.habits.map { ($0, history($0)) }.filter { habit, history in
            habit.isScheduled(on: today, calendar: format.calendar) || history.isDone(on: today)
        }
    }

    private var todayDoneCount: Int {
        todayCounted.filter { $0.1.isDone(on: format.today) }.count
    }

    var ringProgress: Double {
        let total = todayCounted.count
        return total > 0 ? Double(todayDoneCount) / Double(total) : 0
    }

    var ringLabel: String { "\(todayDoneCount)/\(todayCounted.count)" }

    var summary: String {
        let total = todayCounted.count, done = todayDoneCount
        if total > 0, done == total { return L10n.Habits.allDoneToday }
        return L10n.Habits.progress(done, L10n.Plural.habitsOf(total))
    }

    var summarySubtitle: String {
        let best = repository.habits
            .map { ($0, history($0).stats) }
            .max { $0.1.current < $1.1.current }
        guard let (habit, stats) = best, stats.current > 0 else { return L10n.Habits.markToStart }
        return L10n.Habits.longestStreak(habit.name, text.streak(stats))
    }

    var week: [WeekBar] {
        let calendar = format.calendar
        let today = format.today
        let letters = format.veryShortWeekdays
        let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let histories = repository.habits.map(history)

        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            var fraction: Double?
            if day <= today {
                var counted = 0, done = 0
                for history in histories {
                    switch history.state(on: day) {
                    case .done: counted += 1; done += 1
                    case .missed, .today: counted += 1
                    default: break
                    }
                }
                fraction = counted > 0 ? Double(done) / Double(counted) : 0
            }
            return WeekBar(id: day, letter: letters[offset], fraction: fraction, isToday: day == today)
        }
    }

    // MARK: - Список

    var rows: [Row] {
        let today = format.today
        let text = text
        return repository.habits.map { habit in
            let history = history(habit)
            let value = history.value(on: today)
            let isDone = history.isDone(on: today)
            let scheduled = habit.isScheduled(on: today, calendar: format.calendar)
            let schedule = text.schedule(of: habit)
            let progressText = habit.kind == .check
                ? ""
                : "\(text.value(value)) / \(text.value(habit.target)) \(text.unit(of: habit)) · "

            let subtitle: String = if history.isSkipped(on: today) {
                L10n.Habits.skippedToday
            } else if !scheduled && !isDone {
                L10n.Habits.restDayPrefix + schedule
            } else {
                progressText + schedule
            }

            return Row(
                id: habit.id,
                name: habit.name,
                symbolName: habit.symbolName,
                colorHex: habit.colorHex,
                subtitle: subtitle,
                isMeasurable: habit.kind != .check,
                progress: habit.target > 0 ? min(1, value / habit.target) : 0,
                streak: String(history.stats.current),
                isDone: isDone
            )
        }
    }

    // MARK: - Действия

    /// Нажатие на кольцо: шаг вперёд, а у выполненной — сброс.
    func tap(_ id: UUID) {
        guard let habit = habit(id) else { return }
        let today = format.today
        let before = history(habit)
        let previous = before.value(on: today)
        let wasSkipped = before.isSkipped(on: today)
        // `HabitHistory` хранит ссылки на живые отметки: после `setValue` `before` видит новое значение.
        let wasDone = before.isDone(on: today)
        let next = wasDone ? 0 : min(habit.target, previous + habit.step)
        repository.setValue(next, for: habit, on: today)

        let after = history(habit)
        guard !wasDone, after.isDone(on: today) else { return }
        toasts.show(L10n.Habits.doneToast(habit.name, text.streak(after.stats))) { [repository] in
            if wasSkipped {
                repository.setSkipped(true, for: habit, on: today)
            } else {
                repository.setValue(previous, for: habit, on: today)
            }
        }
    }

    func open(_ id: UUID) {
        path.append(id)
    }

    func startCreating(_ suggestion: HabitSuggestion? = nil) {
        editorRequest = .new(suggestion)
    }

    /// Запрос «Добавить привычку» с другого экрана.
    var wantsNewHabit: Bool { navigator.wantsNewHabit }

    func handleNewHabitRequest() {
        guard navigator.wantsNewHabit else { return }
        navigator.wantsNewHabit = false
        path = []
        startCreating()
    }

    private func habit(_ id: UUID) -> Habit? {
        repository.habits.first { $0.id == id }
    }
}
