import Foundation
import Testing
@testable import TickFlow

/// Экраны привычек работают с настоящим `SwiftDataHabitRepository` в памяти:
/// статистика зависит от того, как репозиторий хранит отметки (удаление при 0, сброс пропуска).
/// Сегодня — воскресенье 08.11.2026; привычки по умолчанию начаты 01.11.
@MainActor
final class HabitScreenContext {
    let fixture: ModelFixture
    let clock = FixedClock("2026-11-08 09:00")
    let settings = FakeSettingsRepository()
    let toasts = ToastCenter(sleep: { _ in try await Task.sleep(for: .seconds(3600)) })
    let navigator = AppNavigator()
    let reminders = FakeReminderScheduler()
    private var cached: SwiftDataHabitRepository?

    init() throws {
        fixture = try ModelFixture()
    }

    /// Репозиторий создаётся после того, как тест добавил привычки.
    var repository: SwiftDataHabitRepository {
        if let cached { return cached }
        try? fixture.context.save()
        let repository = SwiftDataHabitRepository(
            context: fixture.context, clock: clock, calendar: TestCalendar.moscow, reminders: reminders
        )
        cached = repository
        return repository
    }

    func habits() -> HabitsViewModel {
        HabitsViewModel(habits: repository, settings: settings, toasts: toasts, navigator: navigator, clock: clock)
    }

    func detail(_ habit: Habit) -> HabitDetailViewModel {
        HabitDetailViewModel(id: habit.id, habits: repository, settings: settings, toasts: toasts, clock: clock)
    }

    func editor(_ request: HabitEditorRequest) -> HabitEditorViewModel {
        HabitEditorViewModel(request: request, habits: repository, settings: settings, toasts: toasts, navigator: navigator, clock: clock)
    }

    func value(_ habit: Habit, _ day: String) -> Double {
        habit.log(on: date(day), calendar: TestCalendar.moscow)?.value ?? 0
    }

    func isSkipped(_ habit: Habit, _ day: String) -> Bool {
        habit.log(on: date(day), calendar: TestCalendar.moscow)?.isSkipped ?? false
    }
}

// MARK: - HabitsViewModel

@MainActor
struct HabitsViewModelTests {
    let context: HabitScreenContext
    var fixture: ModelFixture { context.fixture }

    init() throws {
        context = try HabitScreenContext()
    }

    @Test func emptyScreen() {
        let screen = context.habits()
        #expect(!screen.hasHabits)
        #expect(screen.ringLabel == "0/0")
        #expect(screen.ringProgress == 0)
        #expect(screen.summarySubtitle == "Отмечайте привычки, чтобы начать серию")
        #expect(screen.dateLabel == "Воскресенье, 8 ноября")
        #expect(screen.suggestions.map(\.name) == ["Чтение", "Пить воду", "Тренировка", "Медитация", "Узнать новое"])
    }

    @Test func todaySummaryCountsScheduledOrDone() {
        let done = fixture.habit("Чтение")
        fixture.done(done, "2026-11-08")
        fixture.habit("Вода")
        // Пн, Ср, Пт — сегодня (вс) не запланирована и не учитывается.
        fixture.habit("Спорт", frequency: .specificDays, weekdays: [2, 4, 6])
        let screen = context.habits()

        #expect(screen.ringLabel == "1/2")
        #expect(screen.ringProgress == 0.5)
        #expect(screen.summary == "1 из 2 привычек выполнено")
    }

    @Test func doneOnRestDayIsCounted() {
        let sport = fixture.habit("Спорт", frequency: .specificDays, weekdays: [2, 4, 6])
        fixture.done(sport, "2026-11-08")
        let screen = context.habits()
        #expect(screen.ringLabel == "1/1")
        #expect(screen.summary == "На сегодня всё выполнено")
    }

    @Test func longestStreakSubtitle() {
        let reading = fixture.habit("Чтение")
        fixture.done(reading, "2026-11-06", "2026-11-07", "2026-11-08")
        let water = fixture.habit("Вода")
        fixture.done(water, "2026-11-08")
        #expect(context.habits().summarySubtitle == "Самая длинная серия: Чтение, 3 дня")
    }

    @Test func weekBars() {
        context.clock.now = date("2026-11-04 09:00") // среда
        let reading = fixture.habit("Чтение")
        fixture.done(reading, "2026-11-02", "2026-11-03")
        let water = fixture.habit("Вода")
        fixture.done(water, "2026-11-02")
        let week = context.habits().week

        #expect(week.map(\.letter) == ["П", "В", "С", "Ч", "П", "С", "В"])
        #expect(week.map(\.fraction) == [1, 0.5, 0, nil, nil, nil, nil])
        #expect(week.map(\.isToday) == [false, false, true, false, false, false, false])
    }

    @Test func rowSubtitles() throws {
        let check = fixture.habit("Чтение")
        let water = fixture.habit("Вода", kind: .amount, target: 2, unit: "л")
        fixture.log(water, "2026-11-08", value: 1.5)
        let sport = fixture.habit("Спорт", frequency: .specificDays, weekdays: [2, 4, 6])
        let walk = fixture.habit("Прогулка")
        fixture.log(walk, "2026-11-08", skipped: true)
        let rows = context.habits().rows

        let checkRow = try #require(rows.first { $0.id == check.id })
        #expect(checkRow.subtitle == "Каждый день")
        #expect(!checkRow.isMeasurable)
        #expect(!checkRow.isDone)
        #expect(checkRow.streak == "0")

        let waterRow = try #require(rows.first { $0.id == water.id })
        #expect(waterRow.subtitle == "1,5 / 2 л · Каждый день")
        #expect(waterRow.isMeasurable)
        #expect(waterRow.progress == 0.75)

        #expect(rows.first { $0.id == sport.id }?.subtitle == "День отдыха · Пн, Ср, Пт")
        #expect(rows.first { $0.id == walk.id }?.subtitle == "Пропущено сегодня · серия сохранена")
    }

    @Test func tapMarksDoneWithUndo() {
        let habit = fixture.habit("Чтение")
        fixture.done(habit, "2026-11-07")
        let screen = context.habits()

        screen.tap(habit.id)
        #expect(context.value(habit, "2026-11-08") == 1)
        #expect(screen.rows.first?.isDone == true)
        #expect(context.toasts.current?.message == "«Чтение» выполнено · серия 2 дня")

        context.toasts.performUndo()
        #expect(context.value(habit, "2026-11-08") == 0)
        #expect(screen.rows.first?.isDone == false)
    }

    @Test func tapOnDoneHabitResets() {
        let habit = fixture.habit("Чтение")
        fixture.done(habit, "2026-11-08")
        let screen = context.habits()
        screen.tap(habit.id)
        #expect(context.value(habit, "2026-11-08") == 0)
        #expect(context.toasts.current == nil)
    }

    @Test func tapStepsMeasurableHabit() {
        let habit = fixture.habit("Вода", kind: .amount, target: 2, unit: "л")
        let screen = context.habits()

        screen.tap(habit.id)
        #expect(context.value(habit, "2026-11-08") == 1)
        #expect(context.toasts.current == nil)

        screen.tap(habit.id)
        #expect(context.value(habit, "2026-11-08") == 2)
        #expect(context.toasts.current?.message == "«Вода» выполнено · серия 1 день")

        context.toasts.performUndo()
        #expect(context.value(habit, "2026-11-08") == 1)
    }

    @Test func undoAfterSkippedDayRestoresSkip() {
        let habit = fixture.habit("Чтение")
        fixture.log(habit, "2026-11-08", skipped: true)
        let screen = context.habits()

        screen.tap(habit.id)
        #expect(!context.isSkipped(habit, "2026-11-08"))
        context.toasts.performUndo()
        #expect(context.isSkipped(habit, "2026-11-08"))
    }

    @Test func navigation() throws {
        let habit = fixture.habit()
        let screen = context.habits()
        screen.open(habit.id)
        #expect(screen.path == [habit.id])

        let suggestion = try #require(HabitSuggestion.all.first)
        screen.startCreating(suggestion)
        #expect(screen.editorRequest?.suggestion?.name == suggestion.name)
        #expect(screen.editorRequest?.habit == nil)

        screen.tap(UUID())
        #expect(context.toasts.current == nil)
    }

    @Test func newHabitRequestFromOtherScreen() {
        let habit = fixture.habit()
        let screen = context.habits()
        screen.open(habit.id)
        screen.handleNewHabitRequest()
        #expect(screen.editorRequest == nil)

        context.navigator.openNewHabit()
        #expect(screen.wantsNewHabit)
        screen.handleNewHabitRequest()
        #expect(screen.path.isEmpty)
        #expect(screen.editorRequest != nil)
        #expect(!context.navigator.wantsNewHabit)
    }
}

// MARK: - HabitDetailViewModel

@MainActor
struct HabitDetailViewModelTests {
    let context: HabitScreenContext
    var fixture: ModelFixture { context.fixture }

    init() throws {
        context = try HabitScreenContext()
    }

    @Test func missingHabit() {
        _ = context.repository
        let detail = HabitDetailViewModel(
            id: UUID(), habits: context.repository, settings: context.settings, toasts: context.toasts, clock: context.clock
        )
        #expect(detail.isMissing)
        #expect(detail.name == "")
        #expect(detail.meta == "")
        #expect(detail.stats.isEmpty)
        #expect(detail.cells.isEmpty)
        #expect(detail.trend.isEmpty)
        #expect(detail.infoRows.isEmpty)
        #expect(detail.skipTitle == "")
        detail.skipOrReset()
        detail.edit()
        #expect(detail.editorRequest == nil)
    }

    @Test func headerAndStatsAtRecord() {
        let habit = fixture.habit("Чтение")
        fixture.done(habit, "2026-11-06", "2026-11-07", "2026-11-08")
        let detail = context.detail(habit)

        #expect(!detail.isMissing)
        #expect(detail.name == "Чтение")
        #expect(detail.meta == "Каждый день · Отметить выполнение")
        #expect(detail.stats.map(\.title) == ["Текущая серия", "Лучшая серия", "Выполнение", "Всего"])
        #expect(detail.stats.map(\.value) == ["3 дня", "3 дня", "38%", "3"])
        #expect(detail.stats.map(\.detail) == ["Личный рекорд", "За всё время", "За 30 дней", "Раз выполнено"])
    }

    @Test func statsBelowRecord() {
        let habit = fixture.habit("Чтение", start: "2026-10-25")
        fixture.done(habit, "2026-10-26", "2026-10-27", "2026-10-28", "2026-10-29", "2026-10-30", "2026-11-07", "2026-11-08")
        let current = context.detail(habit).stats[0]
        #expect(current.value == "2 дня")
        #expect(current.detail == "Ещё 3 дня до рекорда")
    }

    /// Текущее поведение: у новой привычки без серии подпись — «Ещё 0 дней до рекорда».
    @Test func statsForFreshHabit() {
        let detail = context.detail(fixture.habit("Новая", start: "2026-11-08"))
        #expect(detail.stats[0].detail == "Ещё 0 дней до рекорда")
    }

    @Test func weeklyGoalStatsDetail() {
        let detail = context.detail(fixture.habit(frequency: .weeklyGoal, timesPerWeek: 2))
        #expect(detail.stats[2].detail == "За 4 недели")
        #expect(detail.stats[0].value == "0 нед.")
    }

    @Test func monthNavigation() {
        let detail = context.detail(fixture.habit())
        #expect(detail.monthTitle == "Ноябрь 2026")
        #expect(detail.canShowNextMonth)
        detail.showNextMonth()
        #expect(detail.monthTitle == "Декабрь 2026")
        #expect(!detail.canShowNextMonth)
        detail.showNextMonth()
        #expect(detail.monthTitle == "Декабрь 2026")
        detail.showPreviousMonth()
        detail.showPreviousMonth()
        #expect(detail.monthTitle == "Октябрь 2026")
        #expect(detail.weekdaySymbols.first == "П")
    }

    @Test func monthCells() throws {
        let habit = fixture.habit()
        fixture.done(habit, "2026-11-05")
        let cells = context.detail(habit).cells

        #expect(cells.count == 36) // 6 пустых + 30 дней
        #expect(cells.prefix(6).allSatisfy { $0.day == nil })
        let days = cells.filter { $0.day != nil }
        #expect(days.first?.number == "1")
        #expect(days[3].state == .missed)
        #expect(days[4].state == .done)
        #expect(days[7].state == .today)
        #expect(days[8].state == .planned)
    }

    @Test func selectingDayShowsInfo() throws {
        let habit = fixture.habit("Вода", kind: .amount, target: 2, unit: "л")
        fixture.log(habit, "2026-11-05", value: 1)
        fixture.log(habit, "2026-11-06", value: 2)
        let detail = context.detail(habit)

        detail.select(date("2026-11-06"))
        #expect(detail.selectedInfo == "Пт, 6 нояб. · Выполнено")
        #expect(detail.cells.filter(\.isSelected).map(\.number) == ["6"])

        detail.select(date("2026-11-05"))
        #expect(detail.selectedInfo == "Чт, 5 нояб. · Не выполнено. Ничего страшного, завтра новый день · 1 из 2 л")

        // Повторное нажатие снимает выбор, `nil` игнорируется.
        detail.select(date("2026-11-05"))
        #expect(detail.selectedInfo == nil)
        detail.select(nil)
        #expect(detail.selectedInfo == nil)

        detail.select(date("2026-11-06"))
        detail.showPreviousMonth()
        #expect(detail.selectedInfo == nil)
    }

    @Test func weeklyTrend() {
        let habit = fixture.habit()
        fixture.done(habit, "2026-11-06", "2026-11-07", "2026-11-08")
        let trend = context.detail(habit).trend

        #expect(trend.count == 8)
        #expect(trend.first?.label == "−7 н")
        #expect(trend.last?.label == "Сейчас")
        #expect(trend.last?.isCurrent == true)
        // Неделя 02–08.11: 3 из 7 учтённых дней.
        #expect(trend.last?.value == "43%")
        // До старта привычки дней не учитывается.
        #expect(trend.first?.fraction == 0)
    }

    @Test func infoRowsAndFootnote() {
        let habit = fixture.habit("Чтение")
        habit.reminderEnabled = true
        habit.reminderMinute = 1290
        let detail = context.detail(habit)

        #expect(detail.infoRows.map(\.title) == ["Цель", "Частота", "Напоминание", "Дни отдыха"])
        #expect(detail.infoRows.map(\.value) == ["Отметить выполнение", "Каждый день", "21:30", "Разрешены"])
        #expect(detail.footnote == "Пропуски и дни отдыха не прерывают серию. Будущие дни не учитываются.")

        context.settings.settings.habitRemindersEnabled = false
        context.settings.settings.allowsRestDays = false
        context.settings.settings.skippedDaysKeepStreak = false
        #expect(detail.infoRows.map(\.value)[2...] == ["Выкл.", "Выкл."])
        #expect(detail.footnote == "Дни отдыха не прерывают серию. Будущие дни не учитываются.")
    }

    @Test func skipAndUndoSkip() {
        let habit = fixture.habit()
        let detail = context.detail(habit)
        #expect(detail.skipTitle == "Пропустить сегодня")

        detail.skipOrReset()
        #expect(context.isSkipped(habit, "2026-11-08"))
        #expect(context.toasts.current?.message == "Сегодня пропущено. Серия сохранена")
        #expect(detail.skipTitle == "Отменить пропуск")

        detail.skipOrReset()
        #expect(!context.isSkipped(habit, "2026-11-08"))
        #expect(detail.skipTitle == "Пропустить сегодня")
    }

    @Test func skipMessageWithoutKeepingStreak() {
        context.settings.settings.skippedDaysKeepStreak = false
        let detail = context.detail(fixture.habit())
        detail.skipOrReset()
        #expect(context.toasts.current?.message == "Сегодня пропущено")
    }

    @Test func undoSkipRestoresPartialValue() {
        let habit = fixture.habit("Вода", kind: .amount, target: 2, unit: "л")
        fixture.log(habit, "2026-11-08", value: 1)
        let detail = context.detail(habit)

        detail.skipOrReset()
        #expect(context.value(habit, "2026-11-08") == 0)
        context.toasts.performUndo()
        #expect(!context.isSkipped(habit, "2026-11-08"))
        #expect(context.value(habit, "2026-11-08") == 1)
    }

    @Test func unmarkDoneWithUndo() {
        let habit = fixture.habit()
        fixture.done(habit, "2026-11-08")
        let detail = context.detail(habit)
        #expect(detail.skipTitle == "Отметить как невыполненное")

        detail.skipOrReset()
        #expect(context.value(habit, "2026-11-08") == 0)
        #expect(context.toasts.current?.message == "Отметка снята")

        context.toasts.performUndo()
        #expect(context.value(habit, "2026-11-08") == 1)
    }

    @Test func editOpensEditor() {
        let habit = fixture.habit()
        let detail = context.detail(habit)
        detail.edit()
        #expect(detail.editorRequest?.habit === habit)
    }
}

// MARK: - HabitEditorViewModel

@MainActor
struct HabitEditorViewModelTests {
    let context: HabitScreenContext
    var fixture: ModelFixture { context.fixture }

    init() throws {
        context = try HabitScreenContext()
    }

    @Test func newHabitDefaults() {
        context.settings.settings.habitRemindersEnabled = false
        let editor = context.editor(.new())
        #expect(editor.isNew)
        #expect(editor.title == "Новая привычка")
        #expect(editor.saveTitle == "Добавить")
        #expect(editor.kind == .check)
        #expect(editor.frequency == .daily)
        #expect(!editor.reminderEnabled)
        #expect(editor.reminderLabel == "09:00")
        #expect(editor.startLabel == "Сегодня")
        #expect(editor.suggestions.count == 5)
        #expect(!editor.canSave)
        #expect(HabitEditorViewModel.units == ["раз", "л", "стр.", "стак."])
        #expect(editor.kindOptions.count == 3)
        #expect(editor.frequencyOptions.count == 3)
        #expect(editor.symbols == AppPalette.habitSymbols)
    }

    @Test func suggestionFillsDraft() throws {
        let water = try #require(HabitSuggestion.all.first { $0.kind == .amount })
        let editor = context.editor(.new(water))
        #expect(editor.name == "Пить воду")
        #expect(editor.kind == .amount)
        #expect(editor.target == 2)
        #expect(editor.unit == "л")
        #expect(editor.targetLabel == "2 л")

        let reading = try #require(HabitSuggestion.all.first)
        editor.apply(reading)
        #expect(editor.kind == .duration)
        #expect(editor.targetLabel == "20 мин")
        // Единица меняется только у количественных подсказок.
        #expect(editor.unit == "л")
    }

    @Test func kindChangeResetsTarget() {
        let editor = context.editor(.new())
        editor.kindSelection = .duration
        #expect(editor.target == 20)
        #expect(editor.isMeasurable)
        #expect(!editor.isAmount)

        editor.selectKind(.amount)
        #expect(editor.target == 8)
        #expect(editor.isAmount)

        editor.incrementTarget()
        editor.selectKind(.amount)
        #expect(editor.target == 9)

        editor.selectKind(.check)
        #expect(editor.target == 1)
        #expect(!editor.isMeasurable)
    }

    @Test func targetStepsDependOnKindAndUnit() {
        let editor = context.editor(.new())
        editor.selectKind(.duration)
        editor.incrementTarget()
        #expect(editor.target == 25)
        editor.decrementTarget()
        editor.decrementTarget()
        #expect(editor.target == 15)

        editor.selectKind(.amount)
        editor.selectUnit("л")
        #expect(editor.target == 2)
        editor.incrementTarget()
        #expect(editor.target == 2.25)
        #expect(editor.targetLabel == "2,25 л")
        for _ in 0..<20 { editor.decrementTarget() }
        #expect(editor.target == 0.25)

        editor.selectUnit("стак.")
        #expect(editor.target == 8)
        editor.selectUnit("стак.")
        #expect(editor.target == 8)
    }

    @Test func weekdaysFollowFirstWeekdayAndValidate() {
        let editor = context.editor(.new())
        editor.name = "Спорт"
        editor.frequency = .specificDays
        #expect(editor.isSpecificDays)
        #expect(editor.weekdayOptions.map(\.id) == [2, 3, 4, 5, 6, 7, 1])
        #expect(editor.weekdayOptions.map(\.letter).first == "П")
        #expect(editor.weekdayOptions.filter(\.isOn).map(\.id) == [2, 3, 4, 5, 6])

        for day in [2, 3, 4, 5, 6] { editor.toggleWeekday(day) }
        #expect(!editor.canSave)
        editor.toggleWeekday(7)
        #expect(editor.canSave)
    }

    @Test func timesPerWeekIsClamped() {
        let editor = context.editor(.new())
        editor.frequency = .weeklyGoal
        #expect(editor.isWeeklyGoal)
        for _ in 0..<10 { editor.incrementTimesPerWeek() }
        #expect(editor.timesPerWeekLabel == "7")
        for _ in 0..<10 { editor.decrementTimesPerWeek() }
        #expect(editor.timesPerWeekLabel == "1")
    }

    @Test func reminderTimeWrapsAroundMidnight() {
        let editor = context.editor(.new())
        for _ in 0..<36 { editor.decrementReminder() }
        #expect(editor.reminderLabel == "00:00")
        editor.decrementReminder()
        #expect(editor.reminderLabel == "23:45")
        editor.incrementReminder()
        #expect(editor.reminderLabel == "00:00")
    }

    @Test func savingNewHabit() throws {
        context.navigator.selectedTab = .calendar
        let editor = context.editor(.new())
        editor.name = "  Медитация "
        editor.selectKind(.duration)
        editor.selectSymbol("leaf")
        editor.selectColor("#399E62")
        editor.reminderEnabled = true
        editor.save()

        let habit = try #require(context.repository.habits.first)
        #expect(habit.name == "Медитация")
        #expect(habit.kind == .duration)
        #expect(habit.target == 20)
        #expect(habit.unit == "мин")
        #expect(habit.step == 5)
        #expect(habit.symbolName == "leaf")
        #expect(habit.colorHex == "#399E62")
        #expect(habit.reminderEnabled)
        #expect(editor.isFinished)
        #expect(context.navigator.selectedTab == .habits)
        #expect(context.toasts.current?.message == "Привычка добавлена · Медитация")

        context.toasts.performUndo()
        #expect(context.repository.habits.isEmpty)
    }

    @Test func checkHabitIsSavedWithoutUnit() throws {
        let editor = context.editor(.new())
        editor.name = "Тренировка"
        editor.save()
        let habit = try #require(context.repository.habits.first)
        #expect(habit.unit == "")
        #expect(habit.target == 1)
    }

    @Test func editingExistingHabit() throws {
        let habit = fixture.habit("Вода", kind: .amount, target: 2, unit: "л", frequency: .specificDays, weekdays: [2, 4])
        let editor = context.editor(.edit(habit))

        #expect(!editor.isNew)
        #expect(editor.title == "Изменить привычку")
        #expect(editor.saveTitle == "Сохранить")
        #expect(editor.suggestions.isEmpty)
        #expect(editor.weekdayOptions.filter(\.isOn).map(\.id) == [2, 4])
        #expect(editor.startLabel == "Вс, 1 нояб.")

        editor.name = "Вода днём"
        editor.save()
        #expect(habit.name == "Вода днём")
        #expect(context.repository.habits.count == 1)
        #expect(context.toasts.current?.message == "Привычка обновлена")
    }

    @Test func deletingHabit() {
        let habit = fixture.habit("Чтение")
        let editor = context.editor(.edit(habit))
        editor.requestDelete()
        #expect(editor.isDeleteConfirmationPresented)
        editor.confirmDelete()
        #expect(context.repository.habits.isEmpty)
        #expect(context.toasts.current?.message == "Привычка «Чтение» удалена")
        #expect(editor.isFinished)
    }

    @Test func deleteWithoutHabitDoesNothing() {
        let editor = context.editor(.new())
        editor.confirmDelete()
        #expect(!editor.isFinished)
    }
}
