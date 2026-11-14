import Foundation
import Testing
@testable import TickFlow

/// Учёт времени в строках задач и в редакторе. Сегодня — 08.11.2026, 09:00.
@MainActor
struct TaskTimeTrackingTests {
    let fixture: ModelFixture
    let clock = FixedClock("2026-11-08 09:00")
    let toasts = ToastCenter(sleep: { _ in try await Task.sleep(for: .seconds(3600)) })
    let entries = FakeTimeEntryRepository()
    let settings = FakeSettingsRepository()
    let work: TaskList
    let home: TaskList
    let repository: FakeTaskRepository
    let focus: FocusEngine

    init() throws {
        fixture = try ModelFixture()
        work = fixture.list("Работа", color: "#111111")
        work.tracksTimeByDefault = true
        home = fixture.list("Дом", color: "#222222")
        repository = FakeTaskRepository(lists: [work, home])
        focus = FocusEngine(entries: entries, tasks: repository, settings: settings, clock: clock,
                            alerts: FakeFocusAlertScheduler(), defaults: makeIsolatedDefaults(), autoTick: false)
    }

    private func entry(_ task: TaskItem, _ start: String, _ end: String, kind: TimeEntryKind = .focus,
                       status: TimeEntryStatus = .completed) {
        entries.add(TimeEntryDraft(task: task, start: date(start), end: date(end), kind: kind, status: status))
    }

    private func editor(_ task: TaskItem?) -> TaskEditorViewModel {
        if let task { repository.insert([task]) }
        return TaskEditorViewModel(
            request: task.map { .edit($0) } ?? .new(day: nil, startMinute: nil, endDay: nil, list: home),
            settings: AppSettings(), tasks: repository, lists: repository, toasts: toasts,
            focus: focus, timeEntries: entries, clock: clock
        )
    }

    private func tasksScreen(_ tasks: [TaskItem]) -> TasksViewModel {
        repository.insert(tasks)
        return TasksViewModel(
            tasks: repository, lists: repository, settings: settings, filter: TaskFilterStore(),
            toasts: toasts, navigator: AppNavigator(), focus: focus, clock: clock
        )
    }

    // MARK: - Строка задачи

    @Test func rowCarriesTrackingOnlyWhenEnabled() throws {
        let tracked = fixture.task("Отчёт", due: "2026-11-08 11:30", minutes: 90, list: work)
        entry(tracked, "2026-11-08 08:00", "2026-11-08 08:25")
        let plain = fixture.task("Уборка", list: home)
        let done = fixture.task("Готово", list: work, completed: true)
        let format = makeFormat(clock: clock)

        let row = TaskRowItem(task: tracked, format: format, allTasks: [])
        #expect(row.tracking == TaskRowItem.Tracking(trackedMinutes: 25, estimateMinutes: 90, canStart: true))
        #expect(TaskRowItem(task: plain, format: format, allTasks: []).tracking == nil)
        #expect(TaskRowItem(task: done, format: format, allTasks: []).tracking?.canStart == false)
    }

    @Test func rowTimerStartsTimerThenOpensScreen() {
        let task = fixture.task("Отчёт", list: work)
        let screen = tasksScreen([task])
        #expect(screen.canTrackTime)

        screen.timerTapped(task.id)
        #expect(focus.run?.mode == .timer)
        #expect(!focus.isScreenPresented)

        screen.timerTapped(task.id)
        #expect(focus.screenHost == .root)
    }

    @Test func headerFocusOpensIdleSession() {
        let screen = tasksScreen([])
        screen.openFocus()
        #expect(focus.isScreenPresented)
        #expect(focus.run?.taskID == nil)
        #expect(!focus.isActive)
    }

    @Test func screenWithoutEngineHasNoTimer() {
        let screen = TasksViewModel(tasks: repository, lists: repository, settings: settings, filter: TaskFilterStore(),
                                    toasts: toasts, navigator: AppNavigator(), clock: clock)
        #expect(!screen.canTrackTime)
    }

    // MARK: - Переключатель в редакторе

    @Test func trackingFollowsSelectedCategoryForNewTask() {
        let editor = editor(nil)
        #expect(!editor.tracksTime)
        editor.selectCategory(work.id)
        #expect(editor.tracksTime)
        #expect(!editor.showsTimeBlock)
    }

    @Test func togglingTrackingOnNewTaskGoesIntoDraft() throws {
        let editor = editor(nil)
        editor.title = "Новая"
        editor.toggleTracking()
        #expect(editor.tracksTime)
        #expect(toasts.current?.message == "Учёт времени включён для этой задачи")
        editor.save()
        #expect(try #require(repository.savedDrafts.last).draft.trackingOverride == true)
    }

    @Test func togglingTrackingOnSavedTaskAppliesImmediately() {
        let task = fixture.task("Отчёт", list: work)
        let editor = editor(task)
        #expect(editor.showsTimeBlock)

        editor.toggleTracking()
        #expect(task.trackingOverride == false)
        #expect(!editor.showsTimeBlock)
        #expect(toasts.current?.message == "Учёт времени выключен для этой задачи")
    }

    // MARK: - Блок «Потрачено»

    @Test func summaryComparesTrackedWithEstimate() {
        let task = fixture.task("Отчёт", due: "2026-11-08 11:30", minutes: 90, list: work)
        entry(task, "2026-11-07 10:00", "2026-11-07 11:00")
        let editor = editor(task)

        #expect(editor.timeSummary.summary == "1 ч потрачено")
        #expect(editor.timeSummary.balance == "Осталось 30 мин")
        #expect(editor.timeSummary.estimateText == "1 ч 30 мин")

        editor.adjustEstimate(by: -45)
        #expect(task.estimateMinutes == 45)
        #expect(editor.timeSummary.isOver)
        #expect(editor.timeSummary.balance == "15 мин сверх оценки")

        editor.adjustEstimate(by: -60)
        #expect(task.estimateMinutes == 0)
        #expect(editor.timeSummary.balance == "Без оценки")
        #expect(editor.timeSummary.progress == 1)
    }

    @Test func liveSessionCountsTowardSummary() {
        let task = fixture.task("Отчёт", list: work)
        let editor = editor(task)
        editor.startFocus()
        #expect(focus.screenHost == .editor)
        #expect(editor.isLiveHere)

        clock.advance(minutes: 10)
        focus.refresh()
        #expect(editor.timeSummary.trackedMinutes == 10)
        editor.toggleLivePause()
        #expect(focus.run?.isRunning == false)
    }

    @Test func startTimerDoesNotOpenScreen() {
        let task = fixture.task("Отчёт", list: work)
        let editor = editor(task)
        editor.startTimer()
        #expect(focus.run?.mode == .timer)
        #expect(!focus.isScreenPresented)
        editor.openLive()
        #expect(focus.screenHost == .editor)
    }

    @Test func entriesShowLatestThreeWithoutBreaks() {
        let task = fixture.task("Отчёт", list: work)
        entry(task, "2026-11-08 08:00", "2026-11-08 08:25")
        entry(task, "2026-11-07 10:00", "2026-11-07 10:17", status: .interrupted)
        entry(task, "2026-11-06 10:00", "2026-11-06 10:20", kind: .manual)
        entry(task, "2026-11-05 10:00", "2026-11-05 10:25", status: .cancelled)
        entry(task, "2026-11-08 08:25", "2026-11-08 08:30", kind: .breakTime)
        let editor = editor(task)

        #expect(editor.entryCount == 4)
        #expect(editor.entryRows.count == 3)
        #expect(editor.entryRows[0].title == "Сегодня, 08:00 – 08:25")
        #expect(editor.entryRows[0].subtitle == "Фокус")
        #expect(editor.entryRows[1].subtitle == "Фокус · Прервана")
        #expect(editor.entryRows[1].duration == "17 мин")
        #expect(editor.entriesToggleTitle == "Показать все (4)")

        editor.toggleAllEntries()
        #expect(editor.entryRows.count == 4)
        #expect(editor.entryRows[3].isCancelled)
        #expect(editor.entriesToggleTitle == "Свернуть")
    }

    // MARK: - Подписи

    @Test func trackedLabelAndPhaseTexts() {
        #expect(FocusText.tracked(70, estimate: 150) == "1 ч 10 мин / 2 ч 30 мин")
        #expect(FocusText.tracked(25, estimate: nil) == "25 мин")

        var run = FocusRun(mode: .focus, taskID: nil, phase: .shortBreak, total: 300, isActive: true)
        #expect(FocusText.phaseWithState(run) == "Короткий перерыв · Готов")
        run.resume(at: clock.now)
        #expect(FocusText.phaseWithState(run) == "Короткий перерыв")
        run.pause(at: clock.now.addingTimeInterval(10))
        #expect(FocusText.phaseWithState(run) == "Короткий перерыв · Пауза")
        #expect(FocusText.phase(FocusRun(mode: .timer, taskID: nil, total: nil, isActive: true)) == "Таймер")
    }
}
