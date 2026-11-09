import Foundation
import SwiftUI
import Testing
@testable import TickFlow

// MARK: - Settings

@MainActor
struct SettingsViewModelTests {
    let fixture: ModelFixture
    let clock = FixedClock("2026-11-08 09:00")
    let settings = FakeSettingsRepository()
    let tasks = FakeTaskRepository()
    let habits = FakeHabitRepository()
    let toasts = ToastCenter(sleep: { _ in try await Task.sleep(for: .seconds(3600)) })
    let navigator = AppNavigator()
    let reminders = FakeReminderScheduler()
    let sampleLoads = Counter()

    init() throws {
        fixture = try ModelFixture()
    }

    private func screen() -> SettingsViewModel {
        SettingsViewModel(
            settings: settings, tasks: tasks, lists: tasks, habits: habits, timeEntries: FakeTimeEntryRepository(), toasts: toasts, navigator: navigator,
            loadSampleData: { [sampleLoads] in sampleLoads.value += 1 }, clock: clock, reminders: reminders
        )
    }

    @Test func simpleSettingsAreWritten() {
        let screen = screen()
        screen.theme = .dark
        screen.firstWeekday = 1
        screen.uses24HourTime = false
        screen.defaultTaskDuration = 30
        screen.defaultReminder = .atTime
        screen.allowsRestDays = false
        screen.skippedDaysKeepStreak = false

        let saved = settings.settings
        #expect(saved.theme == .dark)
        #expect(saved.firstWeekday == 1)
        #expect(!saved.uses24HourTime)
        #expect(saved.defaultTaskDuration == 30)
        #expect(saved.defaultReminder == .atTime)
        #expect(!saved.allowsRestDays)
        #expect(!saved.skippedDaysKeepStreak)
        #expect(screen.theme == .dark)
        #expect(screen.firstWeekday == 1)
        #expect(!screen.uses24HourTime)
        #expect(screen.defaultTaskDuration == 30)
        #expect(screen.defaultReminder == .atTime)
        #expect(!screen.allowsRestDays)
        #expect(!screen.skippedDaysKeepStreak)
    }

    @Test func options() {
        let screen = screen()
        #expect(screen.themeOptions == AppTheme.allCases)
        #expect(screen.weekdayOptions.map(\.title) == ["Понедельник", "Воскресенье"])
        #expect(screen.calendarModeOptions.map(\.value) == [.day, .threeDay, .week, .month])
        #expect(screen.durationOptions.map(\.value) == [15, 30, 45, 60, 90])
        #expect(screen.reminderOptions == ReminderOption.allCases)
        #expect(screen.systemSettingsURL != nil)
        #expect(!screen.version.isEmpty)
    }

    @Test func defaultCalendarModeAlsoResetsLastMode() {
        settings.settings.lastCalendarMode = .month
        let screen = screen()
        screen.defaultCalendarMode = .day
        #expect(settings.settings.defaultCalendarMode == .day)
        #expect(settings.settings.lastCalendarMode == .day)
        #expect(screen.defaultCalendarMode == .day)
    }

    @Test func workdayHoursAreClamped() {
        let screen = screen()
        #expect(screen.workdayStartLabel == "09:00")
        #expect(screen.workdayEndLabel == "18:00")

        screen.shiftWorkdayStart(-20)
        #expect(settings.settings.workdayStartHour == 0)
        screen.shiftWorkdayEnd(20)
        #expect(settings.settings.workdayEndHour == 24)
        #expect(screen.workdayEndLabel == "00:00")

        screen.shiftWorkdayStart(30)
        #expect(settings.settings.workdayStartHour == 23)
        screen.shiftWorkdayEnd(-5)
        #expect(settings.settings.workdayEndHour == 24)
    }

    @Test func reminderTogglesRescheduleRepositories() {
        let screen = screen()
        screen.taskRemindersEnabled = false
        screen.habitRemindersEnabled = false
        #expect(tasks.rescheduleCalls == [false])
        #expect(habits.rescheduleCalls == [false])
        #expect(!settings.settings.taskRemindersEnabled)
        #expect(!settings.settings.habitRemindersEnabled)

        screen.taskRemindersEnabled = true
        #expect(tasks.rescheduleCalls == [false, true])
        #expect(screen.taskRemindersEnabled)
    }

    @Test func deniedNotificationsTurnTogglesOff() async {
        reminders.denied = true
        let screen = screen()
        #expect(screen.taskRemindersEnabled)
        await screen.refreshAuthorization()
        #expect(screen.notificationsDenied)
        #expect(!screen.taskRemindersEnabled)
        #expect(!screen.habitRemindersEnabled)
        // Сама настройка не меняется: разрешат уведомления — переключатели вернутся.
        #expect(settings.settings.taskRemindersEnabled)

        reminders.denied = false
        await screen.refreshAuthorization()
        #expect(screen.taskRemindersEnabled)
    }

    @Test func categories() throws {
        let work = fixture.list("Работа", color: "#111111")
        fixture.task("A", list: work)
        fixture.task("B", list: work)
        let home = fixture.list("Дом")
        tasks.insert([work, home])
        let screen = screen()

        #expect(screen.categories.map(\.name) == ["Работа", "Дом"])
        #expect(screen.categories.map(\.count) == ["2 задачи", "0 задач"])
        #expect(screen.categories.first?.colorHex == "#111111")

        screen.editCategory(work.id)
        #expect(screen.listEditorRequest?.list === work)
        screen.addCategory()
        let request = try #require(screen.listEditorRequest)
        #expect(request.list == nil)
    }

    @Test func sampleDataAfterConfirmation() {
        let screen = screen()
        screen.requestLoadSample()
        #expect(screen.isLoadSampleConfirmationPresented)
        #expect(sampleLoads.value == 0)
        screen.confirmLoadSample()
        #expect(sampleLoads.value == 1)
        #expect(toasts.current?.message == "Пример данных загружен")
    }

    @Test func exportFile() throws {
        tasks.insert([fixture.task("Отчёт")])
        let file = screen().exportFile
        #expect(file.fileName == "TickFlow-2026-11-08.json")
        let json = try #require(try JSONSerialization.jsonObject(with: file.makeData()) as? [String: Any])
        #expect((json["tasks"] as? [Any])?.count == 1)
    }

    /// Текущее поведение: дата в имени файла берётся в UTC. Ночью по Москве это ещё вчерашний день.
    @Test func exportFileNameUsesUTCDate() {
        clock.now = date("2026-11-08 01:00")
        #expect(screen().exportFile.fileName == "TickFlow-2026-11-07.json")
    }

    @Test func replayOnboarding() {
        settings.settings.hasCompletedOnboarding = true
        navigator.selectedTab = .profile
        screen().replayOnboarding()
        #expect(!settings.settings.hasCompletedOnboarding)
        #expect(navigator.selectedTab == .tasks)
    }
}

/// Счётчик, который можно захватить в `@escaping` замыкании.
@MainActor
final class Counter {
    var value = 0
}

// MARK: - Onboarding

@MainActor
struct OnboardingViewModelTests {
    let settings = FakeSettingsRepository()
    let tasks = FakeTaskRepository()
    let habits = FakeHabitRepository()
    let navigator = AppNavigator()
    let reminders = FakeReminderScheduler()
    let sampleLoads = Counter()

    private func onboarding() -> OnboardingViewModel {
        OnboardingViewModel(
            settings: settings, habits: habits, tasks: tasks, navigator: navigator,
            loadSampleData: { [sampleLoads] in sampleLoads.value += 1 },
            clock: FixedClock("2026-11-08 09:00"), reminders: reminders
        )
    }

    private func goToReminders(_ onboarding: OnboardingViewModel) async {
        await onboarding.primary()
        await onboarding.primary()
        await onboarding.primary()
    }

    @Test func stepsAndButtons() async {
        let onboarding = onboarding()
        #expect(onboarding.stepCount == 5)
        #expect(onboarding.step == .welcome)
        #expect(!onboarding.canSkip)
        #expect(onboarding.primaryTitle == "Начать")
        #expect(onboarding.secondaryTitle == nil)
        #expect(onboarding.features.count == 3)

        await onboarding.primary()
        #expect(onboarding.step == .features)
        #expect(onboarding.canSkip)
        #expect(onboarding.primaryTitle == "Продолжить")

        onboarding.skip()
        #expect(onboarding.step == .personalize)
        onboarding.secondary()
        #expect(onboarding.step == .personalize)

        await onboarding.primary()
        #expect(onboarding.step == .reminders)
        #expect(onboarding.primaryTitle == "Включить напоминания")
        #expect(onboarding.secondaryTitle == "Не сейчас")
        #expect(!onboarding.showsSampleButton)

        onboarding.secondary()
        #expect(onboarding.step == .done)
        #expect(onboarding.remindersAllowed == false)
        #expect(!onboarding.canSkip)
        #expect(onboarding.showsSampleButton)
        #expect(onboarding.stepIndex == 4)
        // С последнего шага дальше не уходим.
        onboarding.skip()
        #expect(onboarding.step == .done)
        #expect(reminders.calls.isEmpty)
    }

    @Test func enablingRemindersAsksPermission() async {
        reminders.grantsAuthorization = false
        let onboarding = onboarding()
        await goToReminders(onboarding)
        await onboarding.primary()
        #expect(reminders.calls == [.requestAuthorization])
        #expect(onboarding.remindersAllowed == false)
        #expect(!onboarding.isRequestingPermission)
        #expect(onboarding.step == .done)
    }

    @Test func personalizationIsClamped() {
        let onboarding = onboarding()
        #expect(onboarding.weekdayOptions.map(\.value) == [2, 1])
        onboarding.shiftStart(-20)
        onboarding.shiftEnd(20)
        #expect(onboarding.workdayStartLabel == "00:00")
        #expect(onboarding.workdayEndLabel == "00:00")
        onboarding.shiftStart(30)
        #expect(onboarding.workdayStartLabel == "23:00")
        onboarding.shiftEnd(-5)
        #expect(onboarding.workdayEndLabel == "00:00")
    }

    @Test func goals() throws {
        let onboarding = onboarding()
        let goal = try #require(OnboardingViewModel.goals.first)
        #expect(OnboardingViewModel.goals.count == 6)
        #expect(!onboarding.isGoalSelected(goal))
        onboarding.toggleGoal(goal)
        #expect(onboarding.isGoalSelected(goal))
        onboarding.toggleGoal(goal)
        #expect(!onboarding.isGoalSelected(goal))
        #expect(OnboardingViewModel.PlanStyle.allCases.map(\.title) == ["Блоки времени", "Простой список дел", "Всего понемногу"])
    }

    @Test func summary() async {
        let onboarding = onboarding()
        #expect(onboarding.summary == "Неделя начинается с понедельника, рабочие часы 09:00 – 18:00. Начните с одной задачи или привычки.")

        onboarding.firstWeekday = 1
        OnboardingViewModel.goals.prefix(2).forEach(onboarding.toggleGoal)
        await goToReminders(onboarding)
        await onboarding.primary()
        #expect(onboarding.summary == "Неделя начинается с воскресенья, рабочие часы 09:00 – 18:00. Напоминания включены. Добавим 2 привычки по вашим целям. Начните с одной задачи или привычки.")
    }

    @Test func summaryWithRemindersOff() async {
        let onboarding = onboarding()
        await goToReminders(onboarding)
        onboarding.secondary()
        #expect(onboarding.summary.contains("Напоминания выключены — их можно включить позже в настройках. "))
    }

    @Test func finishSavesSettingsAndCreatesHabits() async throws {
        let onboarding = onboarding()
        onboarding.firstWeekday = 1
        onboarding.shiftStart(-1)
        onboarding.shiftEnd(1)
        onboarding.selectPlanStyle(.timeBlocks)
        let water = try #require(OnboardingViewModel.goals.first { $0.habit.kind == .amount })
        let read = try #require(OnboardingViewModel.goals.first)
        onboarding.toggleGoal(water)
        onboarding.toggleGoal(read)
        await goToReminders(onboarding)
        await onboarding.primary()
        onboarding.loadSample()

        let saved = settings.settings
        #expect(saved.hasCompletedOnboarding)
        #expect(saved.firstWeekday == 1)
        #expect(saved.workdayStartHour == 8)
        #expect(saved.workdayEndHour == 19)
        #expect(saved.defaultCalendarMode == .day)
        #expect(saved.lastCalendarMode == .day)
        #expect(saved.taskRemindersEnabled)
        #expect(tasks.rescheduleCalls == [true])
        #expect(habits.rescheduleCalls == [true])
        #expect(sampleLoads.value == 1)
        #expect(navigator.selectedTab == .tasks)

        let drafts = habits.savedDrafts.map(\.draft)
        #expect(Set(drafts.map(\.name)) == ["Чтение", "Пить воду"])
        let waterDraft = try #require(drafts.first { $0.kind == .amount })
        #expect(waterDraft.step == 0.25)
        #expect(waterDraft.weekdays == Array(1...7))
        #expect(!waterDraft.reminderEnabled)
        #expect(drafts.first { $0.kind == .duration }?.step == 5)
    }

    @Test func skippedRemindersKeepNotificationSettings() {
        settings.settings.taskRemindersEnabled = false
        let onboarding = onboarding()
        onboarding.selectPlanStyle(.todoList)
        onboarding.loadSample()
        #expect(!settings.settings.taskRemindersEnabled)
        #expect(settings.settings.defaultCalendarMode == .month)
        #expect(tasks.rescheduleCalls.isEmpty)
        #expect(navigator.selectedTab == .tasks)
    }

    @Test func existingHabitIsNotDuplicated() throws {
        let fixture = try ModelFixture()
        habits.insert([fixture.habit("Пить воду")])
        let onboarding = onboarding()
        OnboardingViewModel.goals.filter { $0.habit.kind == .amount }.forEach(onboarding.toggleGoal)
        onboarding.loadSample()
        #expect(habits.savedDrafts.isEmpty)
    }

    @Test func finalButtonsOpenEditorsAfterDismiss() async throws {
        let onboarding = onboarding()
        for _ in 0..<4 { onboarding.skip() }
        #expect(onboarding.step == .done)
        #expect(onboarding.primaryTitle == "Создать первую задачу")
        #expect(onboarding.secondaryTitle == "Добавить первую привычку")

        await onboarding.primary()
        #expect(settings.settings.hasCompletedOnboarding)
        #expect(settings.settings.defaultCalendarMode == .week)
        #expect(!navigator.wantsNewTask)
        try await waitUntil { navigator.wantsNewTask }
        #expect(navigator.selectedTab == .calendar)

        onboarding.secondary()
        try await waitUntil { navigator.wantsNewHabit }
        #expect(navigator.selectedTab == .habits)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<100 where !condition() {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(condition())
    }
}

// MARK: - Root

@MainActor
struct RootViewModelTests {
    let settings = FakeSettingsRepository()
    let toasts = ToastCenter(sleep: { _ in try await Task.sleep(for: .seconds(3600)) })
    let navigator = AppNavigator()

    private var root: RootViewModel { RootViewModel(settings: settings, toasts: toasts, navigator: navigator) }

    @Test func tabIsSharedWithNavigator() {
        let root = root
        root.selectedTab = .habits
        #expect(navigator.selectedTab == .habits)
        navigator.selectedTab = .profile
        #expect(root.selectedTab == .profile)
    }

    @Test func onboardingFollowsSettingsAndIgnoresWrites() {
        let root = root
        #expect(root.isOnboardingPresented)
        // Закрыть онбординг жестом нельзя: значение задаёт только настройка.
        root.isOnboardingPresented = false
        #expect(root.isOnboardingPresented)
        settings.settings.hasCompletedOnboarding = true
        #expect(!root.isOnboardingPresented)
    }

    @Test(arguments: [(AppTheme.system, nil), (.light, .light), (.dark, .dark)] as [(AppTheme, ColorScheme?)])
    func colorScheme(theme: AppTheme, expected: ColorScheme?) {
        settings.settings.theme = theme
        #expect(root.colorScheme == expected)
    }

    @Test func toastAndUndo() {
        let root = root
        var undone = false
        toasts.show("Удалено") { undone = true }
        #expect(root.toast?.message == "Удалено")
        root.undoToast()
        #expect(undone)
        #expect(root.toast?.message == "Изменение отменено")
    }
}

// MARK: - QuickEditorHost

@MainActor
struct QuickEditorHostTests {
    let fixture: ModelFixture

    init() throws {
        fixture = try ModelFixture()
    }

    private func editor() -> TaskEditorViewModel {
        let repository = FakeTaskRepository()
        return TaskEditorViewModel(
            request: .new(day: date("2026-11-08")), settings: AppSettings(),
            tasks: repository, lists: repository,
            toasts: ToastCenter(sleep: { _ in }), clock: FixedClock("2026-11-08 09:00")
        )
    }

    @Test func showCloseFinish() {
        let host = QuickEditorHost()
        let closes = Counter()
        host.close()
        host.finishClose()
        #expect(host.editor == nil)

        let editor = editor()
        host.show(editor) { closes.value += 1 }
        #expect(host.editor === editor)
        #expect(!host.isClosing)

        host.close()
        #expect(host.isClosing)
        #expect(host.editor === editor)
        host.close()
        #expect(host.isClosing)

        host.finishClose()
        #expect(host.editor == nil)
        #expect(!host.isClosing)
        #expect(closes.value == 1)

        // Колбэк вызывается один раз.
        host.finishClose()
        #expect(closes.value == 1)
    }

    @Test func showingNewEditorReplacesCallbackAndResetsClosing() {
        let host = QuickEditorHost()
        let first = Counter(), second = Counter()
        host.show(editor()) { first.value += 1 }
        host.close()
        let next = editor()
        host.show(next) { second.value += 1 }
        #expect(!host.isClosing)
        #expect(host.editor === next)
        host.finishClose()
        #expect(first.value == 0)
        #expect(second.value == 1)
    }
}
