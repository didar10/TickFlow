import Foundation
import Observation

/// Создание и изменение привычки. Правит черновик; в базу — только по «Добавить» / «Сохранить».
@MainActor
@Observable
final class HabitEditorViewModel {
    struct WeekdayOption: Identifiable {
        /// 1 — воскресенье … 7 — суббота.
        let id: Int
        let letter: String
        let isOn: Bool
    }

    static let units = [L10n.Habits.unitTimes, L10n.Habits.unitLiters, L10n.Habits.unitPages, L10n.Habits.unitGlasses]

    var name: String
    private(set) var symbolName: String
    private(set) var colorHex: String
    private(set) var kind: HabitKind
    private(set) var target: Double
    private(set) var unit: String
    var frequency: HabitFrequency
    private(set) var weekdays: Set<Int>
    private(set) var timesPerWeek: Int
    var reminderEnabled: Bool
    private(set) var reminderMinute: Int
    var isDeleteConfirmationPresented = false
    /// Редактор нужно закрыть.
    private(set) var isFinished = false

    @ObservationIgnored private let habit: Habit?
    @ObservationIgnored private let repository: any HabitRepository
    @ObservationIgnored private let settings: any SettingsRepository
    @ObservationIgnored private let toasts: ToastCenter
    @ObservationIgnored private let navigator: AppNavigator

    init(
        request: HabitEditorRequest,
        habits: any HabitRepository,
        settings: any SettingsRepository,
        toasts: ToastCenter,
        navigator: AppNavigator
    ) {
        habit = request.habit
        repository = habits
        self.settings = settings
        self.toasts = toasts
        self.navigator = navigator

        if let habit = request.habit {
            name = habit.name
            symbolName = habit.symbolName
            colorHex = habit.colorHex
            kind = habit.kind
            target = habit.target
            unit = habit.kind == .amount ? habit.unit : L10n.Habits.unitTimes
            frequency = habit.frequency
            weekdays = habit.frequency == .specificDays ? Set(habit.weekdays) : [2, 3, 4, 5, 6]
            timesPerWeek = habit.timesPerWeek
            reminderEnabled = habit.reminderEnabled
            reminderMinute = habit.reminderMinute
        } else {
            name = ""
            symbolName = "book"
            colorHex = "#5B5BD6"
            kind = .check
            target = 1
            unit = L10n.Habits.unitTimes
            frequency = .daily
            weekdays = [2, 3, 4, 5, 6]
            timesPerWeek = 3
            reminderEnabled = settings.settings.habitRemindersEnabled
            reminderMinute = 540
            if let suggestion = request.suggestion { apply(suggestion) }
        }
    }

    private var format: DisplayFormatter { DisplayFormatter(settings: settings.settings) }
    private var text: HabitText { HabitText(format: format) }

    // MARK: - Шапка

    var isNew: Bool { habit == nil }
    var title: String { isNew ? L10n.Habits.new : L10n.HabitEditor.edit }
    var saveTitle: String { isNew ? L10n.Common.add : L10n.Common.save }

    var canSave: Bool {
        !trimmedName.isEmpty && (frequency != .specificDays || !weekdays.isEmpty)
    }

    var suggestions: [HabitSuggestion] { isNew ? HabitSuggestion.all : [] }

    func apply(_ suggestion: HabitSuggestion) {
        name = suggestion.name
        symbolName = suggestion.symbolName
        colorHex = suggestion.colorHex
        kind = suggestion.kind
        target = suggestion.target
        if suggestion.kind == .amount { unit = suggestion.unit }
    }

    // MARK: - Внешний вид

    var symbols: [String] { AppPalette.habitSymbols }
    var colors: [String] { AppPalette.listColors }

    func selectSymbol(_ symbol: String) { symbolName = symbol }
    func selectColor(_ hex: String) { colorHex = hex }

    // MARK: - Отслеживание

    var kindOptions: [(value: HabitKind, title: String)] {
        HabitKind.allCases.map { ($0, $0.title) }
    }

    var kindSelection: HabitKind {
        get { kind }
        set { selectKind(newValue) }
    }

    func selectKind(_ newKind: HabitKind) {
        guard newKind != kind else { return }
        kind = newKind
        switch newKind {
        case .check: target = 1
        case .duration: target = 20
        case .amount: target = unit == L10n.Habits.unitLiters ? 2 : 8
        }
    }

    var isMeasurable: Bool { kind != .check }
    var isAmount: Bool { kind == .amount }

    var targetLabel: String {
        text.value(target) + " " + (kind == .duration ? L10n.Format.minutesUnit : unit)
    }

    private var step: Double {
        switch kind {
        case .check: 1
        case .duration: 5
        case .amount: unit == L10n.Habits.unitLiters ? 0.25 : 1
        }
    }

    func decrementTarget() { target = max(step, (target - step).rounded(toPlaces: 2)) }
    func incrementTarget() { target = (target + step).rounded(toPlaces: 2) }

    func selectUnit(_ newUnit: String) {
        guard newUnit != unit else { return }
        unit = newUnit
        target = newUnit == L10n.Habits.unitLiters ? 2 : 8
    }

    // MARK: - Частота

    var frequencyOptions: [(value: HabitFrequency, title: String)] {
        HabitFrequency.allCases.map { ($0, $0.title) }
    }

    var isSpecificDays: Bool { frequency == .specificDays }
    var isWeeklyGoal: Bool { frequency == .weeklyGoal }

    var weekdayOptions: [WeekdayOption] {
        let symbols = format.calendar.veryShortStandaloneWeekdaySymbols
        return text.weekdayOrder.map { WeekdayOption(id: $0, letter: symbols[$0 - 1], isOn: weekdays.contains($0)) }
    }

    func toggleWeekday(_ day: Int) {
        if weekdays.contains(day) { weekdays.remove(day) } else { weekdays.insert(day) }
    }

    var timesPerWeekLabel: String { String(timesPerWeek) }
    func decrementTimesPerWeek() { timesPerWeek = max(1, timesPerWeek - 1) }
    func incrementTimesPerWeek() { timesPerWeek = min(7, timesPerWeek + 1) }

    // MARK: - Напоминание

    var reminderLabel: String { format.time(minute: reminderMinute) }
    func decrementReminder() { reminderMinute = (reminderMinute + 1440 - 15) % 1440 }
    func incrementReminder() { reminderMinute = (reminderMinute + 15) % 1440 }

    var startLabel: String {
        guard let habit else { return L10n.Common.today }
        return format.relativeDay(format.calendar.startOfDay(for: habit.startDate))
    }

    // MARK: - Действия

    func save() {
        guard canSave else { return }
        let draft = HabitDraft(
            name: trimmedName,
            symbolName: symbolName,
            colorHex: colorHex,
            kind: kind,
            target: kind == .check ? 1 : target,
            unit: kind == .duration ? L10n.Format.minutesUnit : kind == .amount ? unit : "",
            step: step,
            frequency: frequency,
            weekdays: Array(weekdays),
            timesPerWeek: timesPerWeek,
            reminderEnabled: reminderEnabled,
            reminderMinute: reminderMinute
        )
        let saved = repository.save(draft, to: habit)
        if isNew {
            navigator.selectedTab = .habits
            toasts.show(L10n.HabitEditor.addedToast(saved.name)) { [repository] in repository.delete(saved) }
        } else {
            toasts.show(L10n.HabitEditor.updated)
        }
        isFinished = true
    }

    func requestDelete() {
        isDeleteConfirmationPresented = true
    }

    func confirmDelete() {
        guard let habit else { return }
        let name = habit.name
        repository.delete(habit)
        toasts.show(L10n.HabitEditor.deletedToast(name))
        isFinished = true
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10, Double(places))
        return (self * factor).rounded() / factor
    }
}
