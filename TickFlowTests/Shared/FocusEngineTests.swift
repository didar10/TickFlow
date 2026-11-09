import Foundation
import Testing
@testable import TickFlow

@MainActor
struct FocusEngineTests {
    let fixture: ModelFixture
    let clock = FixedClock("2026-11-08 09:00")
    let entries = FakeTimeEntryRepository()
    let alerts = FakeFocusAlertScheduler()
    let settings = FakeSettingsRepository()
    let defaults = makeIsolatedDefaults()
    let task: TaskItem
    let other: TaskItem
    let tasks: FakeTaskRepository

    init() throws {
        fixture = try ModelFixture()
        task = fixture.task("Отчёт")
        other = fixture.task("Письма")
        tasks = FakeTaskRepository(tasks: [task, other])
    }

    private func engine() -> FocusEngine {
        FocusEngine(entries: entries, tasks: tasks, settings: settings, clock: clock, alerts: alerts,
                    defaults: defaults, autoTick: false)
    }

    private func advance(_ minutes: Int, seconds: Int = 0, _ engine: FocusEngine) {
        clock.now = clock.now.addingTimeInterval(TimeInterval(minutes * 60 + seconds))
        engine.refresh()
    }

    private func at(_ time: String) -> Date { date("2026-11-08 " + time) }

    // MARK: - Фокус

    @Test func startFocusRunsAndOpensScreen() throws {
        let engine = engine()
        engine.startFocus(task: task)

        let run = try #require(engine.run)
        #expect(run.mode == .focus)
        #expect(run.phase == .focus)
        #expect(run.total == TimeInterval(25 * 60))
        #expect(run.isRunning && run.isActive)
        #expect(engine.isScreenPresented)
        #expect(engine.task === task)
        #expect(run.endsAt == at("09:25"))

        advance(10, engine)
        #expect(engine.run?.clockText(at: clock.now) == "15:00")
        #expect(engine.liveSeconds(for: task) == 600)
        #expect(engine.trackedMinutes(for: task) == 10)
        #expect(engine.liveSeconds(for: other) == 0)
    }

    @Test func completingFocusSavesEntryAndStartsBreak() throws {
        let engine = engine()
        engine.startFocus(task: task)
        advance(25, engine)

        let entry = try #require(entries.entries.first)
        #expect(entries.entries.count == 1)
        #expect(entry.kind == .focus)
        #expect(entry.status == .completed)
        #expect(entry.task === task)
        #expect(entry.start == at("09:00"))
        #expect(entry.end == at("09:25"))

        let run = try #require(engine.run)
        #expect(run.phase == .shortBreak)
        #expect(run.round == 1)
        #expect(run.total == TimeInterval(5 * 60))
        // Перерыв начался ровно в момент конца фокуса.
        #expect(run.resumedAt == at("09:25"))
        #expect(engine.banner?.title == "Сессия фокуса завершена")
        #expect(engine.banner?.body == "25 мин на «Отчёт» сохранено. Время для перерыва на 5 мин.")
    }

    @Test func breakEndsReadyForNextFocusWithoutAutoStart() throws {
        let engine = engine()
        engine.startFocus(task: task)
        advance(25, engine)
        advance(5, engine)

        #expect(entries.entries.map(\.kind) == [.focus, .breakTime])
        #expect(entries.entries[1].task == nil)
        let run = try #require(engine.run)
        #expect(run.phase == .focus)
        #expect(run.isReady && run.isActive)
        #expect(run.round == 1)
        #expect(engine.banner?.body == "Готовы к сессии 2 из 4?")
    }

    @Test func fourthSessionGetsLongBreakThenCycleRestarts() throws {
        settings.update { $0.focus.autoStartFocus = true }
        let engine = engine()
        engine.startFocus(task: nil)
        // Три полных круга фокус + короткий перерыв.
        for _ in 0..<3 { advance(30, engine) }
        #expect(engine.run?.round == 3)
        advance(25, engine)
        #expect(engine.run?.phase == .longBreak)
        #expect(engine.run?.total == TimeInterval(15 * 60))
        advance(15, engine)
        #expect(engine.run?.phase == .focus)
        #expect(engine.run?.round == 0)
    }

    @Test func missedPhasesInBackgroundCloseAtTheirRealEnd() throws {
        settings.update { $0.focus.autoStartFocus = true }
        let engine = engine()
        engine.startFocus(task: task)
        engine.dismissBanner()
        advance(62, engine)

        // 25 фокус, 5 перерыв, 25 фокус, 5 перерыв, и 2 минуты третьего фокуса.
        #expect(entries.entries.map(\.end) == [at("09:25"), at("09:30"), at("09:55"), at("10:00")])
        #expect(engine.run?.elapsed(at: clock.now) == 120)
        // Фазы кончились, пока приложение было закрыто, — баннер не показывается.
        #expect(engine.banner == nil)
    }

    @Test func pausesAreNotPartOfEntryDuration() throws {
        let engine = engine()
        engine.startFocus(task: task)
        advance(10, engine)
        engine.pause()
        #expect(alerts.pending == nil)
        advance(20, engine)
        #expect(engine.run?.elapsed(at: clock.now) == 600)
        engine.resume()
        #expect(engine.run?.endsAt == at("09:45"))
        #expect(engine.run?.pauseCount == 1)
        advance(15, engine)

        let entry = try #require(entries.entries.first)
        #expect(entry.start == at("09:20"))
        #expect(entry.end == at("09:45"))
    }

    @Test func noAutoBreakLeavesBreakReady() {
        settings.update { $0.focus.autoStartBreaks = false }
        let engine = engine()
        engine.startFocus(task: task)
        advance(25, engine)
        #expect(engine.run?.phase == .shortBreak)
        #expect(engine.run?.isReady == true)
        #expect(engine.isActive)
    }

    @Test func skipBreakSavesBreakAndStartsFocus() throws {
        let engine = engine()
        engine.startFocus(task: task)
        advance(25, engine)
        advance(2, engine)
        engine.skipBreak()

        #expect(entries.entries.map(\.kind) == [.focus, .breakTime])
        #expect(entries.entries[1].durationMinutes == 2)
        let run = try #require(engine.run)
        #expect(run.phase == .focus && run.isRunning)
        #expect(run.round == 1)
    }

    // MARK: - Остановка

    @Test func openFocusPreparesInactiveSessionAndClosingDropsIt() {
        let engine = engine()
        engine.openFocus()
        #expect(engine.run?.isReady == true)
        #expect(!engine.isActive)
        #expect(engine.isScreenPresented)

        engine.closeScreen()
        #expect(engine.run == nil)
        #expect(!engine.isScreenPresented)
    }

    @Test func closingScreenKeepsRunningSession() {
        let engine = engine()
        engine.startFocus(task: task)
        engine.closeScreen()
        #expect(engine.isActive)
        #expect(!engine.isScreenPresented)
        engine.present()
        #expect(engine.isScreenPresented)
    }

    @Test func stoppingMidFocusAsksAndSavesInterrupted() throws {
        let engine = engine()
        engine.startFocus(task: task)
        advance(17, seconds: 10, engine)

        #expect(engine.stop() == .confirm(minutes: 17, of: 25))
        #expect(engine.run?.isRunning == true)
        advance(0, seconds: 20, engine)
        let entry = try #require(engine.saveInterrupted())
        #expect(entry.status == .interrupted)
        #expect(entry.durationMinutes == 18)
        #expect(engine.run == nil)
        #expect(!engine.isScreenPresented)
        #expect(alerts.pending == nil)
    }

    @Test func discardingKeepsCancelledEntry() throws {
        let engine = engine()
        engine.startFocus(task: task)
        advance(5, engine)
        engine.discardSession()
        #expect(entries.entries.first?.status == .cancelled)
        #expect(task.trackedMinutes == 0)
        #expect(engine.run == nil)
    }

    @Test func stoppingReadyOrInactiveSessionSavesNothing() {
        let engine = engine()
        engine.openFocus()
        #expect(engine.stop() == .ended)
        #expect(engine.run == nil)

        settings.update { $0.focus.autoStartFocus = false }
        engine.startFocus(task: task)
        advance(25, engine)
        advance(5, engine)
        #expect(engine.run?.isReady == true)
        #expect(engine.stop() == .ended)
        #expect(entries.entries.count == 2)
    }

    @Test func stoppingBreakEndsCycle() {
        let engine = engine()
        engine.startFocus(task: task)
        advance(26, engine)
        #expect(engine.stop() == .cycleEnded)
        #expect(entries.entries.map(\.kind) == [.focus, .breakTime])
        #expect(engine.run == nil)
    }

    @Test func sessionsShorterThan30SecondsAreNotSaved() {
        let engine = engine()
        engine.startFocus(task: task)
        advance(0, seconds: 20, engine)
        #expect(engine.saveInterrupted() == nil)
        #expect(entries.entries.isEmpty)
    }

    // MARK: - Переключение

    @Test func startingAnotherTaskSavesCurrentAsInterrupted() throws {
        let engine = engine()
        engine.startFocus(task: task)
        advance(10, engine)
        engine.startFocus(task: other)

        #expect(entries.entries.first?.status == .interrupted)
        #expect(entries.entries.first?.task === task)
        #expect(engine.task === other)
        #expect(engine.run?.elapsed(at: clock.now) == 0)
    }

    @Test func startingSameFocusOnlyOpensScreen() {
        let engine = engine()
        engine.startFocus(task: task, present: false)
        #expect(!engine.isScreenPresented)
        advance(3, engine)
        engine.startFocus(task: task, present: false)
        #expect(engine.isScreenPresented)
        #expect(entries.entries.isEmpty)
        #expect(engine.run?.elapsed(at: clock.now) == 180)
    }

    @Test func focusAfterTimerSavesTimerAsCompleted() {
        let engine = engine()
        engine.startTimer(task: other)
        #expect(!engine.isScreenPresented)
        advance(12, engine)
        engine.startFocus(task: task)
        #expect(entries.entries.first?.kind == .timer)
        #expect(entries.entries.first?.status == .completed)
        #expect(entries.entries.first?.task === other)
    }

    @Test func linkingTaskMovesTimeToIt() throws {
        let engine = engine()
        engine.openFocus()
        engine.resume()
        #expect(engine.isActive)
        advance(5, engine)
        engine.linkTask(task)
        advance(20, engine)
        #expect(entries.entries.first?.task === task)
    }

    // MARK: - Таймер

    @Test func timerCountsUpAndStopOffersSave() throws {
        let engine = engine()
        engine.startTimer(task: task)
        advance(65, seconds: 3, engine)
        #expect(engine.run?.clockText(at: clock.now) == "1:05:03")
        #expect(engine.run?.endsAt == nil)
        #expect(alerts.pending == nil)

        let result = engine.stop()
        #expect(result == .saveTimer(start: at("09:00"), end: at("10:05").addingTimeInterval(3)))
        #expect(engine.run?.isRunning == false)

        let entry = try #require(engine.finishTimer(TimeEntryDraft(task: task, start: at("09:00"), end: at("09:50"),
                                                                    kind: .manual)))
        #expect(entry.kind == .timer)
        #expect(entry.durationMinutes == 50)
        #expect(engine.run == nil)
    }

    @Test func timerSaveSheetCanBeCancelledOrDiscarded() {
        let engine = engine()
        engine.startTimer(task: task)
        advance(10, engine)
        _ = engine.stop()
        advance(5, engine)
        engine.continueTimer()
        #expect(engine.run?.isRunning == true)
        advance(5, engine)
        #expect(engine.run?.elapsed(at: clock.now) == 900)

        _ = engine.stop()
        engine.discardTimer(start: at("09:00"), end: at("09:15"))
        #expect(entries.entries.first?.status == .cancelled)
        #expect(engine.run == nil)
    }

    @Test func invalidTimerDraftIsRejected() {
        let engine = engine()
        engine.startTimer(task: task)
        _ = engine.stop()
        #expect(engine.finishTimer(TimeEntryDraft(task: task, start: at("10:00"), end: at("09:00"), kind: .timer)) == nil)
        #expect(engine.run != nil)
    }

    // MARK: - Уведомления

    @Test func alertIsScheduledForPhaseEnd() throws {
        let engine = engine()
        engine.startFocus(task: task)
        let alert = try #require(alerts.pending)
        #expect(alert.date == at("09:25"))
        #expect(alert.title == "Сессия фокуса завершена")

        advance(25, engine)
        #expect(alerts.pending?.date == at("09:30"))
        #expect(alerts.pending?.title == "Перерыв окончен")
    }

    @Test func notificationsOffMeansNoAlertsAndNoBanner() {
        settings.update { $0.focus.sessionNotifications = false }
        let engine = engine()
        engine.startFocus(task: task)
        #expect(alerts.pending == nil)
        advance(25, engine)
        #expect(engine.banner == nil)
    }

    // MARK: - Настройки и хранение

    @Test func settingsChangeAppliesOnlyToPhaseNotStarted() {
        let engine = engine()
        engine.openFocus()
        settings.update { $0.focus.apply(.extended) }
        engine.settingsChanged()
        #expect(engine.run?.total == TimeInterval(50 * 60))

        engine.resume()
        settings.update { $0.focus.apply(.classic) }
        engine.settingsChanged()
        #expect(engine.run?.total == TimeInterval(50 * 60))
    }

    @Test func runningSessionSurvivesRestart() throws {
        let first = engine()
        first.startFocus(task: task)
        advance(10, first)

        clock.now = at("09:28")
        let second = engine()
        // Фокус закончился в 9:25, пока приложение было закрыто, — запись есть, перерыв идёт.
        #expect(entries.entries.first?.end == at("09:25"))
        #expect(second.run?.phase == .shortBreak)
        #expect(second.run?.elapsed(at: clock.now) == 180)
    }

    @Test func inactiveSessionIsNotRestored() {
        let first = engine()
        first.openFocus()
        let second = engine()
        #expect(second.run == nil)
    }

    @Test func liveIntervalCoversOnlyWork() throws {
        let engine = engine()
        #expect(engine.liveInterval == nil)
        engine.startFocus(task: task)
        advance(4, engine)
        let live = try #require(engine.liveInterval)
        #expect(live.start == at("09:00"))
        #expect(live.end == at("09:04"))
        #expect(live.taskID == task.id)
        advance(22, engine)
        #expect(engine.liveInterval == nil)
    }

    // MARK: - Тексты времени

    @Test func clockTexts() {
        #expect(FocusRun.countdown(1500) == "25:00")
        #expect(FocusRun.countdown(0.2) == "0:01")
        #expect(FocusRun.countdown(-5) == "0:00")
        #expect(FocusRun.stopwatch(59) == "0:59")
        #expect(FocusRun.stopwatch(3723) == "1:02:03")
    }

    @Test func progressOfTimerUsesEstimate() {
        var run = FocusRun(mode: .timer, taskID: nil, total: nil, isActive: true)
        run.accumulated = 1800
        #expect(run.progress(at: clock.now, estimateSeconds: 3600, alreadyTracked: 900) == 0.75)
        #expect(run.progress(at: clock.now) == 0.5)
    }
}
