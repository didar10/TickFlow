import Foundation
import Observation

/// Знакомство с приложением: пять шагов, настройки под себя и запрос уведомлений.
@MainActor
@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case welcome, features, personalize, reminders, done
    }

    enum PlanStyle: String, CaseIterable, Identifiable {
        case timeBlocks, todoList, both

        var id: String { rawValue }

        var title: String {
            switch self {
            case .timeBlocks: L10n.Onboarding.planTimeBlocks
            case .todoList: L10n.Onboarding.planTodoList
            case .both: L10n.Onboarding.planBoth
            }
        }
    }

    struct Goal: Identifiable {
        var id: String { title }
        let title: String
        let habit: HabitSuggestion
    }

    struct Feature: Identifiable {
        var id: String { title }
        let symbol: String
        let title: String
        let text: String
    }

    static let goals: [Goal] = [
        Goal(title: L10n.Onboarding.goalRead, habit: HabitSuggestion(name: L10n.Habits.suggestionReading, symbolName: "book", colorHex: "#5B5BD6",
                                                            kind: .duration, target: 20, unit: L10n.Format.minutesUnit)),
        Goal(title: L10n.Onboarding.goalMove, habit: HabitSuggestion(name: L10n.Onboarding.habitExercise, symbolName: "dumbbell",
                                                                    colorHex: "#CF8526", kind: .check, target: 1, unit: "")),
        Goal(title: L10n.Habits.suggestionWater, habit: HabitSuggestion(name: L10n.Habits.suggestionWater, symbolName: "drop", colorHex: "#2A9792",
                                                        kind: .amount, target: 2, unit: L10n.Habits.unitLiters)),
        Goal(title: L10n.Onboarding.goalSleep, habit: HabitSuggestion(name: L10n.Onboarding.habitBedtime, symbolName: "moon", colorHex: "#6C6C70",
                                                          kind: .check, target: 1, unit: "")),
        Goal(title: L10n.Onboarding.goalLanguage, habit: HabitSuggestion(name: L10n.Onboarding.habitLanguage, symbolName: "lightbulb",
                                                         colorHex: "#BE5A96", kind: .duration, target: 15, unit: L10n.Format.minutesUnit)),
        Goal(title: L10n.Onboarding.goalMeditate, habit: HabitSuggestion(name: L10n.Habits.suggestionMeditation, symbolName: "leaf", colorHex: "#399E62",
                                                           kind: .duration, target: 10, unit: L10n.Format.minutesUnit)),
    ]

    let features: [Feature] = [
        Feature(symbol: "calendar", title: L10n.Onboarding.featureTimeTitle,
                text: L10n.Onboarding.featureTimeText),
        Feature(symbol: "checklist", title: L10n.Onboarding.featureTasksTitle,
                text: L10n.Onboarding.featureTasksText),
        Feature(symbol: "checkmark.circle", title: L10n.Onboarding.featureHabitsTitle,
                text: L10n.Onboarding.featureHabitsText),
    ]

    private(set) var step: Step = .welcome
    private(set) var planStyle: PlanStyle = .both
    var firstWeekday: Int
    private(set) var workdayStart: Int
    private(set) var workdayEnd: Int
    private(set) var selectedGoals: Set<String> = []
    private(set) var remindersAllowed: Bool?
    private(set) var isRequestingPermission = false

    @ObservationIgnored private let settings: any SettingsRepository
    @ObservationIgnored private let habits: any HabitRepository
    @ObservationIgnored private let tasks: any TaskRepository
    @ObservationIgnored private let navigator: AppNavigator
    @ObservationIgnored private let loadSampleData: () -> Void
    @ObservationIgnored private let clock: any AppClock
    @ObservationIgnored private let reminders: any ReminderScheduling

    init(
        settings: any SettingsRepository,
        habits: any HabitRepository,
        tasks: any TaskRepository,
        navigator: AppNavigator,
        loadSampleData: @escaping () -> Void,
        clock: any AppClock = SystemClock(),
        reminders: any ReminderScheduling = SystemReminderScheduler()
    ) {
        self.clock = clock
        self.reminders = reminders
        self.settings = settings
        self.habits = habits
        self.tasks = tasks
        self.navigator = navigator
        self.loadSampleData = loadSampleData
        firstWeekday = settings.settings.firstWeekday
        workdayStart = settings.settings.workdayStartHour
        workdayEnd = settings.settings.workdayEndHour
    }

    private var format: DisplayFormatter { DisplayFormatter(settings: settings.settings, clock: clock) }

    // MARK: - Навигация

    var stepCount: Int { Step.allCases.count }
    var stepIndex: Int { step.rawValue }
    var canSkip: Bool { step != .welcome && step != .done }

    var primaryTitle: String {
        switch step {
        case .welcome: L10n.Onboarding.start
        case .features, .personalize: L10n.Onboarding.continue
        case .reminders: L10n.Onboarding.enableReminders
        case .done: L10n.Calendar.createFirstTask
        }
    }

    var secondaryTitle: String? {
        switch step {
        case .reminders: L10n.Onboarding.notNow
        case .done: L10n.Calendar.addFirstHabit
        default: nil
        }
    }

    var showsSampleButton: Bool { step == .done }

    func skip() {
        advance()
    }

    func primary() async {
        switch step {
        case .reminders:
            isRequestingPermission = true
            remindersAllowed = await reminders.requestAuthorization()
            isRequestingPermission = false
            advance()
        case .done:
            finish()
            afterDismiss { $0.openNewTask() }
        default:
            advance()
        }
    }

    func secondary() {
        switch step {
        case .reminders:
            remindersAllowed = false
            advance()
        case .done:
            finish()
            afterDismiss { $0.openNewHabit() }
        default:
            break
        }
    }

    func loadSample() {
        finish()
        loadSampleData()
    }

    // MARK: - Под себя

    var weekdayOptions: [(value: Int, title: String)] { [(2, L10n.Common.monday), (1, L10n.Common.sunday)] }

    func selectPlanStyle(_ style: PlanStyle) { planStyle = style }

    var workdayStartLabel: String { format.time(minute: workdayStart * 60) }
    var workdayEndLabel: String { format.time(minute: workdayEnd * 60) }
    func shiftStart(_ delta: Int) { workdayStart = min(max(0, workdayStart + delta), workdayEnd - 1) }
    func shiftEnd(_ delta: Int) { workdayEnd = min(max(workdayStart + 1, workdayEnd + delta), 24) }

    func isGoalSelected(_ goal: Goal) -> Bool { selectedGoals.contains(goal.id) }

    func toggleGoal(_ goal: Goal) {
        if selectedGoals.contains(goal.id) { selectedGoals.remove(goal.id) } else { selectedGoals.insert(goal.id) }
    }

    // MARK: - Итог

    var summary: String {
        let week = firstWeekday == 2 ? L10n.Onboarding.fromMonday : L10n.Onboarding.fromSunday
        var text = L10n.Onboarding.summaryWeek(week, workdayStartLabel, workdayEndLabel)
        switch remindersAllowed {
        case true?: text += L10n.Onboarding.remindersOn
        case false?: text += L10n.Onboarding.remindersOff
        case nil: break
        }
        let count = selectedGoals.count
        if count > 0 {
            text += L10n.Onboarding.summaryHabits(L10n.Plural.habitsToAdd(count))
        }
        return text + L10n.Onboarding.startWithOne
    }

    // MARK: - Внутреннее

    /// Редактор откроется, когда экран знакомства уже закроется: два экрана сразу SwiftUI не покажет.
    private func afterDismiss(_ action: @escaping (AppNavigator) -> Void) {
        let navigator = navigator
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            action(navigator)
        }
    }

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    private func finish() {
        let mode: CalendarMode = switch planStyle {
        case .timeBlocks: .day
        case .todoList: .month
        case .both: .week
        }
        // Шаг с напоминаниями пропустили — прежние настройки уведомлений не трогаем.
        let allowed = remindersAllowed
        settings.update {
            $0.firstWeekday = firstWeekday
            $0.workdayStartHour = workdayStart
            $0.workdayEndHour = workdayEnd
            $0.defaultCalendarMode = mode
            $0.lastCalendarMode = mode
            if let allowed {
                $0.taskRemindersEnabled = allowed
                $0.habitRemindersEnabled = allowed
            }
            $0.hasCompletedOnboarding = true
        }
        if let allowed {
            tasks.rescheduleReminders(enabled: allowed)
            habits.rescheduleReminders(enabled: allowed)
        }
        createGoalHabits()
        if planStyle == .todoList { navigator.selectedTab = .tasks }
    }

    private func createGoalHabits() {
        let existing = Set(habits.habits.map(\.name))
        for goal in Self.goals where selectedGoals.contains(goal.id) && !existing.contains(goal.habit.name) {
            let habit = goal.habit
            habits.save(HabitDraft(
                name: habit.name, symbolName: habit.symbolName, colorHex: habit.colorHex, kind: habit.kind,
                target: habit.target, unit: habit.unit,
                step: habit.kind == .duration ? 5 : habit.unit == L10n.Habits.unitLiters ? 0.25 : 1,
                frequency: .daily, weekdays: Array(1...7), timesPerWeek: 3,
                reminderEnabled: false, reminderMinute: 540
            ), to: nil)
        }
    }
}
