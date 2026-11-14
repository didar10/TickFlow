import Foundation
import Testing
@testable import TickFlow

@MainActor
struct FocusScreensTests {
    let fixture: ModelFixture
    let clock = FixedClock("2026-11-08 09:00")
    let entries = FakeTimeEntryRepository()
    let alerts = FakeFocusAlertScheduler()
    let settings = FakeSettingsRepository()
    let defaults = makeIsolatedDefaults()
    let toasts = ToastCenter(sleep: { _ in try await Task.sleep(for: .seconds(3600)) })
    let task: TaskItem
    let tasks: FakeTaskRepository
    let focus: FocusEngine

    init() throws {
        fixture = try ModelFixture()
        let work = fixture.list("Работа", color: "#2E7D5B")
        task = fixture.task("Отчёт", due: "2026-11-08 10:00", minutes: 60, list: work)
        tasks = FakeTaskRepository(tasks: [task, fixture.task("Письма")])
        focus = FocusEngine(entries: entries, tasks: tasks, settings: settings, clock: clock, alerts: alerts,
                            defaults: defaults, autoTick: false)
    }

    private var format: DisplayFormatter {
        DisplayFormatter(settings: settings.settings, base: TestCalendar.moscow, clock: clock)
    }

    private func at(_ time: String) -> Date { date("2026-11-08 " + time) }

    private func advance(_ minutes: Int) {
        clock.now = clock.now.addingTimeInterval(TimeInterval(minutes * 60))
        focus.refresh()
    }

    private func editor(_ mode: TimeEntryEditorViewModel.Mode, task: TaskItem?, _ start: String, _ end: String) -> TimeEntryEditorViewModel {
        TimeEntryEditorViewModel(mode: mode, task: task, start: at(start), end: at(end), entries: entries,
                                 tasks: tasks, focus: focus, toasts: toasts, format: format)
    }

    private var factory: TimeEntryEditorFactory {
        { mode, task, start, end in
            TimeEntryEditorViewModel(mode: mode, task: task, start: start, end: end, entries: entries,
                                     tasks: tasks, focus: focus, toasts: toasts, format: format)
        }
    }

    private func screen(host: FocusEngine.ScreenHost = .root, history: (() -> Void)? = nil) -> FocusScreenViewModel {
        FocusScreenViewModel(focus: focus, host: host, entries: entries, tasks: tasks, format: format,
                             stopFlow: FocusStopFlow(focus: focus, toasts: toasts, makeEntryEditor: factory),
                             onOpenHistory: history)
    }

    // MARK: - Запись времени

    @Test func manualEntrySavesWithChangedTimes() throws {
        let editor = editor(.new, task: task, "10:00", "10:30")
        #expect(editor.title == "Добавить время")
        #expect(editor.durationText == "30 мин")
        editor.stepEnd(15)
        editor.stepStart(-5)
        editor.save()

        let entry = try #require(entries.entries.first)
        #expect(entry.kind == .manual)
        #expect(entry.status == .completed)
        #expect(entry.start == at("09:55"))
        #expect(entry.end == at("10:45"))
        #expect(entry.task === task)
        #expect(editor.isFinished)
        #expect(toasts.current?.message == "Запись сохранена · 50 мин")
    }

    @Test func endBeforeStartIsInvalid() {
        let editor = editor(.new, task: nil, "10:00", "10:30")
        editor.stepStart(30)
        #expect(!editor.isValid)
        #expect(editor.errorText == "Конец раньше начала.")
        editor.save()
        #expect(entries.entries.isEmpty)
        #expect(!editor.isFinished)
    }

    @Test func dayCannotMoveIntoFuture() {
        let editor = editor(.new, task: nil, "10:00", "10:30")
        #expect(!editor.canStepDayForward)
        editor.stepDay(1)
        #expect(editor.day == format.today)
        editor.stepDay(-1)
        #expect(editor.day == date("2026-11-07 00:00"))
        #expect(editor.canStepDayForward)
    }

    @Test func entryAcrossMidnightEndsAtEndOfDay() {
        let editor = TimeEntryEditorViewModel(mode: .new, task: nil, start: at("23:30"), end: date("2026-11-09 00:20"),
                                              entries: entries, tasks: tasks, focus: focus, toasts: toasts, format: format)
        #expect(editor.endText == "23:59")
    }

    @Test func editKeepsKindAndDeleteMarksDeletion() throws {
        let entry = try #require(entries.add(TimeEntryDraft(task: task, start: at("08:00"), end: at("08:25"), kind: .focus, status: .interrupted)))
        let editor = editor(.edit(entry), task: task, "08:00", "08:25")
        #expect(editor.canDelete && !editor.canDiscard)
        editor.selectTask(id: nil)
        editor.stepEnd(5)
        editor.save()
        #expect(entry.kind == .focus)
        #expect(entry.status == .interrupted)
        #expect(entry.task == nil)
        #expect(entry.end == at("08:30"))

        let again = self.editor(.edit(entry), task: nil, "08:00", "08:30")
        again.delete()
        #expect(entries.entries.isEmpty)
        #expect(again.didDelete && again.isFinished)
    }

    @Test func taskOptionsSkipCompletedAndPutUndatedLast() {
        let done = fixture.task("Готово", due: "2026-11-08 08:00", completed: true)
        let tasks = FakeTaskRepository(tasks: [fixture.task("Без даты"), task, done])
        let options = TaskPickerOption.options(from: tasks.tasks, format: format)
        #expect(options.map(\.title) == ["Отчёт", "Без даты"])
        #expect(options.first?.when == "Сегодня")
        #expect(options.first?.colorHex == "#2E7D5B")
    }

    // MARK: - Остановка

    @Test func stoppingFocusAsksAndSavesInterrupted() throws {
        let flow = FocusStopFlow(focus: focus, toasts: toasts, makeEntryEditor: factory)
        focus.startFocus(task: task)
        advance(12)
        flow.stop()
        #expect(flow.confirmation == .init(minutes: 12, total: 25))
        #expect(focus.isActive)

        flow.saveInterrupted()
        let entry = try #require(entries.entries.first)
        #expect(entry.status == .interrupted)
        #expect(entry.durationMinutes == 12)
        #expect(flow.confirmation == nil)
        #expect(focus.run == nil)
        #expect(toasts.current?.message == "Сохранено 12 мин · Прервана")
    }

    @Test func keepGoingLeavesFocusRunning() {
        let flow = FocusStopFlow(focus: focus, toasts: toasts, makeEntryEditor: factory)
        focus.startFocus(task: task)
        advance(5)
        flow.stop()
        flow.keepGoing()
        #expect(flow.confirmation == nil)
        #expect(focus.run?.isRunning == true)
        #expect(entries.entries.isEmpty)
    }

    @Test func stoppingTimerOpensSaveSheetAndSaves() throws {
        let flow = FocusStopFlow(focus: focus, toasts: toasts, makeEntryEditor: factory)
        focus.startTimer(task: task)
        advance(40)
        flow.stop()
        let editor = try #require(flow.timerEntry)
        #expect(editor.title == "Сохранить время")
        #expect(editor.startText == "09:00" && editor.endText == "09:40")
        #expect(focus.run?.isRunning == false)

        editor.save()
        flow.timerSheetDismissed()
        let entry = try #require(entries.entries.first)
        #expect(entry.kind == .timer)
        #expect(entry.durationMinutes == 40)
        #expect(focus.run == nil)
        #expect(flow.timerEntry == nil)
    }

    @Test func swipingTimerSheetAwayKeepsTimerRunning() throws {
        let flow = FocusStopFlow(focus: focus, toasts: toasts, makeEntryEditor: factory)
        focus.startTimer(task: task)
        advance(10)
        flow.stop()
        #expect(flow.timerEntry != nil)
        flow.timerSheetDismissed()
        #expect(focus.run?.isRunning == true)
        #expect(entries.entries.isEmpty)
    }

    @Test func discardingTimerRecordsCancelledEntry() throws {
        let flow = FocusStopFlow(focus: focus, toasts: toasts, makeEntryEditor: factory)
        focus.startTimer(task: task)
        advance(10)
        flow.stop()
        try #require(flow.timerEntry).discard()
        flow.timerSheetDismissed()
        #expect(entries.entries.first?.status == .cancelled)
        #expect(focus.run == nil)
    }

    // MARK: - Экран фокуса

    @Test func readyScreenShowsPresetsAndCannotStop() {
        focus.openFocus()
        let screen = screen()
        #expect(screen.title == "Фокус")
        #expect(screen.timeText == "25:00")
        #expect(screen.showsPresets)
        #expect(!screen.canStop)
        #expect(!screen.showsSkip)
        #expect(screen.dots.count == 4)
        #expect(screen.dots.first?.isCurrent == true)
        #expect(screen.taskTitle == L10n.Focus.noTaskLink)
        #expect(screen.presets.first { $0.isSelected }?.preset == .classic)
    }

    @Test func presetChangesReadySession() {
        focus.openFocus()
        let screen = screen()
        screen.selectPreset(.extended)
        #expect(settings.settings.focus.focusMinutes == 50)
        #expect(screen.timeText == "50:00")

        screen.selectPreset(.custom)
        #expect(screen.isSettingsPresented)
        #expect(settings.settings.focus.preset == .extended)
    }

    @Test func runningScreenControlsAndBreak() {
        focus.startFocus(task: task)
        let screen = screen()
        #expect(screen.primaryTitle == L10n.Focus.pause)
        #expect(screen.canStop && !screen.showsPresets)
        #expect(screen.taskTitle == "Отчёт")
        #expect(screen.counterText == L10n.Focus.sessionOf(1, 4))

        advance(25)
        #expect(screen.isBreak)
        #expect(screen.showsSkip)
        #expect(screen.stopTitle == L10n.Focus.endCycle)
        #expect(screen.counterText == L10n.Focus.sessionsDone(1, 4))
        #expect(screen.dots.filter(\.isDone).count == 1)

        screen.skipBreak()
        #expect(!screen.isBreak)
    }

    @Test func linkingTaskFromScreen() {
        focus.openFocus()
        let screen = screen()
        screen.linkTask(task.id)
        #expect(focus.task === task)
        screen.linkTask(nil)
        #expect(focus.task == nil)
    }

    @Test func todaySummaryCountsWorkAndLiveTime() {
        entries.add(TimeEntryDraft(task: task, start: at("07:00"), end: at("07:25"), kind: .focus))
        entries.add(TimeEntryDraft(task: task, start: at("07:25"), end: at("07:30"), kind: .breakTime))
        entries.add(TimeEntryDraft(task: nil, start: at("08:00"), end: at("08:20"), kind: .focus, status: .cancelled))
        focus.startFocus(task: task)
        advance(10)
        #expect(screen().todayText == L10n.Focus.todaySummary("35 мин", L10n.Focus.sessions(1)))
    }

    @Test func historyOnlyFromRootScreen() {
        var opened = false
        focus.openFocus()
        let root = screen(history: { opened = true })
        #expect(root.canOpenHistory)
        #expect(!screen(host: .editor, history: {}).canOpenHistory)
        root.openHistory()
        #expect(opened)
        #expect(!focus.isScreenPresented)
    }

    // MARK: - Настройки

    @Test func manualDurationMakesPresetCustom() {
        let model = FocusSettingsViewModel(settings: settings, focus: focus)
        model.stepFocus(3)
        #expect(settings.settings.focus.focusMinutes == 40)
        #expect(model.preset == .custom)
        model.stepShortBreak(2)
        #expect(FocusSettingsViewModel.summary(settings.settings.focus) == "40/7 мин")

        model.preset = .classic
        #expect(settings.settings.focus.focusMinutes == 25)
        #expect(FocusSettingsViewModel.summary(settings.settings.focus) == "25/5")
    }

    @Test func settingsStayInRange() {
        let model = FocusSettingsViewModel(settings: settings, focus: focus)
        for _ in 0..<40 { model.stepFocus(1); model.stepLongBreakEvery(1) }
        #expect(settings.settings.focus.focusMinutes == FocusSettings.focusRange.upperBound)
        #expect(settings.settings.focus.longBreakEvery == FocusSettings.longBreakEveryRange.upperBound)
        for _ in 0..<40 { model.stepShortBreak(-1) }
        #expect(settings.settings.focus.shortBreakMinutes == FocusSettings.shortBreakRange.lowerBound)
    }

    // MARK: - Сессия

    @Test func sessionSheetShowsPlanAndDeletes() throws {
        let entry = try #require(entries.add(TimeEntryDraft(task: task, start: at("08:00"), end: at("08:25"), kind: .focus, status: .interrupted)))
        var openedTask: TaskItem?
        let model = SessionDetailViewModel(entry: entry, entries: entries, toasts: toasts, format: format,
                                           makeEntryEditor: factory, onOpenTask: { openedTask = $0 })
        #expect(model.title == "Отчёт")
        #expect(model.pills.map(\.text) == ["Работа", L10n.Focus.kindFocus, L10n.Focus.statusInterrupted])
        #expect(model.actualRows.map(\.value).dropFirst().first == "08:00")
        #expect(model.planRows.last?.value == L10n.Focus.totalOf("25 мин", "1 ч"))

        model.openTask()
        #expect(openedTask === task)

        model.delete()
        #expect(entries.entries.isEmpty)
        #expect(model.isFinished)
    }

    @Test func deletingFromEditClosesSession() throws {
        let entry = try #require(entries.add(TimeEntryDraft(task: nil, start: at("08:00"), end: at("08:25"), kind: .manual)))
        let model = SessionDetailViewModel(entry: entry, entries: entries, toasts: toasts, format: format, makeEntryEditor: factory)
        #expect(model.title == "Ручная запись")
        #expect(model.planRows.isEmpty)
        model.edit()
        try #require(model.editor).delete()
        model.editorClosed()
        #expect(model.isFinished)
        #expect(model.editor == nil)
    }

    // MARK: - Редактор задачи

    @Test func editorAddsManualEntryEndingNow() throws {
        clock.now = at("14:07")
        task.trackingOverride = true
        let model = TaskEditorViewModel(
            request: .edit(task), settings: settings.settings, tasks: tasks, lists: tasks,
            toasts: toasts, focus: focus, timeEntries: entries, makeEntryEditor: factory, clock: clock
        )
        model.addManualEntry()
        let editor = try #require(model.entryEditor)
        #expect(editor.startText == "13:35")
        #expect(editor.endText == "14:05")
        #expect(editor.task === task)
    }
}
