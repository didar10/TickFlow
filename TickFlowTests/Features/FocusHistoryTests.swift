import Foundation
import Testing
@testable import TickFlow

/// Сегодня — воскресенье 08.11.2026, 09:00.
@MainActor
struct FocusHistoryTests {
    let fixture: ModelFixture
    let clock = FixedClock("2026-11-08 09:00")
    let entries = FakeTimeEntryRepository()
    let settings = FakeSettingsRepository()
    let repository = FakeTaskRepository()
    let task: TaskItem
    let other: TaskItem

    init() throws {
        fixture = try ModelFixture()
        let work = fixture.list("Работа", color: "#2A9792")
        task = fixture.task("Отчёт", due: "2026-11-08 10:00", minutes: 60, list: work)
        other = fixture.task("Письма")
        repository.insert([task, other])
    }

    @discardableResult
    private func entry(_ start: String, _ end: String, kind: TimeEntryKind = .focus,
                       status: TimeEntryStatus = .completed, task: TaskItem? = nil) -> TimeEntry? {
        entries.add(TimeEntryDraft(task: task, start: date(start), end: date(end), kind: kind, status: status))
    }

    private func history() -> FocusHistoryViewModel {
        FocusHistoryViewModel(entries: entries, settings: settings, clock: clock)
    }

    private func insights(_ range: InsightsViewModel.Range = .week) -> InsightsViewModel {
        let model = InsightsViewModel(tasks: repository, habits: FakeHabitRepository(), settings: settings,
                                      navigator: AppNavigator(), timeEntries: entries, clock: clock)
        model.range = range
        return model
    }

    // MARK: - История

    @Test func statsCountLastSevenDaysOfWork() {
        entry("2026-11-08 08:00", "2026-11-08 08:25", task: task)
        entry("2026-11-08 08:25", "2026-11-08 08:30", kind: .breakTime)
        entry("2026-11-05 10:00", "2026-11-05 10:50", kind: .timer)
        entry("2026-11-04 10:00", "2026-11-04 10:10", status: .cancelled)
        entry("2026-10-20 10:00", "2026-10-20 11:00")

        let model = history()
        #expect(model.stats.map(\.value) == ["25 мин", "1 ч 15 мин", "2"])
        #expect(model.bars.count == 7)
        #expect(model.bars.last?.minutes == 25)
        #expect(model.bars.last?.isCurrent == true)
        #expect(model.bars.first { $0.minutes == 50 }?.id == 3)
    }

    @Test func daysAreNewestFirstAndSkipBreaks() throws {
        entry("2026-11-08 08:00", "2026-11-08 08:25", task: task)
        entry("2026-11-08 08:30", "2026-11-08 08:40", status: .cancelled)
        entry("2026-11-08 08:25", "2026-11-08 08:30", kind: .breakTime)
        entry("2026-11-07 10:00", "2026-11-07 10:14", status: .interrupted)

        let days = history().days
        #expect(days.map(\.title) == ["Сегодня", "Вчера"])
        let today = try #require(days.first)
        #expect(today.rows.map(\.title) == ["Сессия фокуса", "Отчёт"])
        #expect(today.rows.first?.badge == .cancelled)
        #expect(today.summary == L10n.Calendar.trackedTotal("25 мин", L10n.Focus.sessions(2)))
        #expect(days.last?.rows.first?.badge == .interrupted)
    }

    @Test func filterKeepsMatchingStatus() {
        entry("2026-11-08 08:00", "2026-11-08 08:25")
        entry("2026-11-07 10:00", "2026-11-07 10:14", status: .interrupted)
        let model = history()
        model.filter = .interrupted
        #expect(model.days.flatMap(\.rows).count == 1)
        model.filter = .cancelled
        #expect(model.isEmpty)
    }

    @Test func showsSevenDaysUntilAskedForMore() {
        for day in 1...9 {
            entry(String(format: "2026-10-%02d 10:00", day + 20), String(format: "2026-10-%02d 10:25", day + 20))
        }
        let model = history()
        #expect(model.days.count == 7)
        #expect(model.hasMore)
        model.showEarlier()
        #expect(model.days.count == 9)
        #expect(!model.hasMore)
        model.filter = .completed
        #expect(model.hasMore)
    }

    // MARK: - Аналитика

    @Test func timeReportTotalsAndKpis() {
        entry("2026-11-08 08:00", "2026-11-08 08:25", task: task)
        entry("2026-11-08 08:25", "2026-11-08 08:30", kind: .breakTime)
        entry("2026-11-06 10:00", "2026-11-06 10:14", status: .interrupted, task: task)
        entry("2026-11-05 10:00", "2026-11-05 10:50", kind: .manual, task: other)
        entry("2026-11-04 10:00", "2026-11-04 10:30", status: .cancelled)

        let model = insights()
        #expect(model.hasTimeData)
        let report = model.timeReport
        #expect(report.kpis.map(\.value) == ["25 мин", "1 ч 29 мин", "1", "30 мин"])
        #expect(report.kpis[2].detail == L10n.Focus.completedShare("33%"))
        #expect(report.kpis[3].detail == L10n.Focus.longest("50 мин"))
        #expect(report.focusMinutes == 89)
        #expect(report.breakMinutes == 5)
        #expect(report.bars.count == 7)
        #expect(report.bars.last?.minutes == 25)
    }

    @Test func timeReportGroupsCategoriesAndTasks() throws {
        entry("2026-11-08 07:00", "2026-11-08 08:10", task: task)
        entry("2026-11-07 10:00", "2026-11-07 10:20", task: other)
        entry("2026-11-07 11:00", "2026-11-07 11:15")

        let report = insights().timeReport
        #expect(report.categories.map(\.name) == ["Работа", L10n.Common.noCategory, L10n.Focus.noTask])
        #expect(report.categories.last?.colorHex == nil)
        let first = try #require(report.tasks.first)
        #expect(first.title == "Отчёт")
        #expect(first.estimate == 60)
        #expect(first.isOver)
        #expect(first.value == "1 ч 10 мин / 1 ч")
        #expect(report.taskScale == 70)
    }

    @Test func noTimeDataHidesSection() {
        #expect(!insights().hasTimeData)
    }
}
