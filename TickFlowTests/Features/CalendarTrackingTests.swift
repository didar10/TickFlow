import Foundation
import Testing
@testable import TickFlow

/// Сегодня — воскресенье 08.11.2026, 09:00. Неделя с понедельника: 02.11–08.11.
@MainActor
struct CalendarTrackingTests {
    let fixture: ModelFixture
    let clock = FixedClock("2026-11-08 09:00")
    let repository = FakeTaskRepository()
    let settings = FakeSettingsRepository()
    let entries = FakeTimeEntryRepository()
    let toasts = ToastCenter(sleep: { _ in try await Task.sleep(for: .seconds(3600)) })
    let focus: FocusEngine
    let task: TaskItem

    init() throws {
        fixture = try ModelFixture()
        task = fixture.task("Отчёт", due: "2026-11-08 07:00", list: fixture.list("Работа", color: "#2A9792"))
        repository.insert([task])
        focus = FocusEngine(entries: entries, tasks: repository, settings: settings, clock: clock,
                            alerts: FakeFocusAlertScheduler(), defaults: makeIsolatedDefaults(), autoTick: false)
    }

    private func calendar(_ mode: CalendarMode) -> CalendarViewModel {
        settings.settings.defaultCalendarMode = mode
        let format = DisplayFormatter(settings: settings.settings, base: TestCalendar.moscow, clock: clock)
        return CalendarViewModel(
            tasks: repository, lists: repository, settings: settings, filter: TaskFilterStore(), toasts: toasts,
            navigator: AppNavigator(), loadSampleData: {}, timeEntries: entries, focus: focus,
            makeSessionDetail: { [entries, toasts] entry, onOpenTask in
                SessionDetailViewModel(entry: entry, entries: entries, toasts: toasts, format: format,
                                       makeEntryEditor: { _, _, _, _ in fatalError() }, onOpenTask: onOpenTask)
            },
            clock: clock
        )
    }

    @discardableResult
    private func entry(_ start: String, _ end: String, kind: TimeEntryKind = .focus,
                       status: TimeEntryStatus = .completed, task: TaskItem? = nil) -> TimeEntry? {
        entries.add(TimeEntryDraft(task: task, start: date(start), end: date(end), kind: kind, status: status))
    }

    @Test func weekShowsWorkEntriesAsSessions() throws {
        entry("2026-11-03 10:00", "2026-11-03 10:25", status: .interrupted, task: task)
        entry("2026-11-03 10:25", "2026-11-03 10:30", kind: .breakTime)
        entry("2026-11-05 11:00", "2026-11-05 11:10", status: .cancelled)
        entry("2026-11-07 15:00", "2026-11-07 15:40", kind: .manual)

        let calendar = calendar(.week)
        let sessions = calendar.sessions
        #expect(sessions.count == 2)
        let first = try #require(sessions.first)
        #expect(first.dayIndex == 1)
        #expect(first.startMinute == 600 && first.endMinute == 625)
        #expect(first.title == "Отчёт")
        #expect(first.colorHex == "#2A9792")
        #expect(first.isInterrupted)
        #expect(first.detail == "Фокус · 25 мин · остановлена")
        #expect(sessions.last?.title == "Ручная запись")
        #expect(calendar.sessionDayIndexes == [1, 5])
    }

    @Test func monthHasNoSessionBlocksButTrackedLabels() {
        entry("2026-11-03 10:00", "2026-11-03 10:25")
        entry("2026-11-03 12:00", "2026-11-03 12:45")
        let calendar = calendar(.month)
        #expect(calendar.sessions.isEmpty)
        let cell = calendar.monthCells.first { $0.id == date("2026-11-03") }
        #expect(cell?.tracked == "1ч10мин")
        #expect(calendar.monthCells.first { $0.id == date("2026-11-04") }?.tracked == "")
    }

    @Test func liveFocusNarrowsToday() {
        let calendar = calendar(.week)
        #expect(calendar.liveDayIndex == nil)
        focus.startFocus(task: task, present: false)
        #expect(calendar.liveDayIndex == 6)
        #expect(calendar.sessionDayIndexes == [6])
        #expect(calendar.showsLiveTracked)
    }

    @Test func breakIsNotLive() {
        let calendar = calendar(.day)
        focus.startFocus(task: task, present: false)
        clock.now = date("2026-11-08 09:25")
        focus.refresh()
        #expect(focus.run?.phase == .shortBreak)
        #expect(calendar.liveDayIndex == nil)
    }

    @Test func trackedRowsForSelectedDay() throws {
        entry("2026-11-08 07:00", "2026-11-08 07:25", status: .interrupted, task: task)
        entry("2026-11-08 08:00", "2026-11-08 08:30", kind: .timer)
        let calendar = calendar(.month)
        let rows = calendar.trackedRows
        #expect(rows.map(\.time) == ["07:00 – 07:25 · Фокус", "08:00 – 08:30 · Таймер"])
        #expect(rows.first?.badge == .interrupted)
        #expect(rows.last?.hasTask == false)
        #expect(calendar.trackedMinutes == 55)
    }

    @Test func openingTaskFromSessionWaitsForSheetToClose() throws {
        let saved = try #require(entry("2026-11-08 07:00", "2026-11-08 07:25", task: task))
        let calendar = calendar(.day)
        calendar.openSession(saved.id)
        let detail = try #require(calendar.sessionDetail)
        detail.openTask()
        #expect(calendar.editorRequest == nil)
        calendar.sessionClosed()
        #expect(calendar.sessionDetail == nil)
        #expect(calendar.editorRequest?.task === task)
    }
}
