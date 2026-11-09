import Foundation
import Testing
@testable import TickFlow

@MainActor
struct TimeTrackingModelTests {
    let fixture: ModelFixture

    init() throws {
        fixture = try ModelFixture()
    }

    private func entry(
        _ start: String, _ end: String,
        kind: TimeEntryKind = .focus, status: TimeEntryStatus = .completed, task: TaskItem? = nil
    ) -> TimeEntry {
        let entry = TimeEntry(start: date(start), end: date(end), kind: kind, status: status, task: task)
        fixture.context.insert(entry)
        return entry
    }

    // MARK: - TimeEntry

    @Test func durationIsRoundedToMinutes() {
        let entry = TimeEntry(start: date("2026-11-08 09:00"), end: date("2026-11-08 09:25").addingTimeInterval(40),
                              kind: .focus)
        #expect(entry.durationMinutes == 26)
    }

    @Test func breaksAndCancelledDoNotCountAsWork() {
        #expect(entry("2026-11-08 09:00", "2026-11-08 09:25").countsAsWork)
        #expect(entry("2026-11-08 09:00", "2026-11-08 09:25", status: .interrupted).countsAsWork)
        #expect(entry("2026-11-08 09:00", "2026-11-08 09:25", kind: .manual).countsAsWork)
        #expect(!entry("2026-11-08 09:25", "2026-11-08 09:30", kind: .breakTime).countsAsWork)
        #expect(!entry("2026-11-08 09:00", "2026-11-08 09:25", status: .cancelled).countsAsWork)
    }

    @Test func unknownRawValuesFallBack() {
        let entry = entry("2026-11-08 09:00", "2026-11-08 09:25")
        entry.kindRaw = 99
        entry.statusRaw = 99
        #expect(entry.kind == .focus)
        #expect(entry.status == .completed)
    }

    // MARK: - Трекинг задачи

    @Test func trackingFollowsCategoryUnlessOverridden() {
        let work = fixture.list("Работа")
        work.tracksTimeByDefault = true
        let task = fixture.task(list: work)
        #expect(task.tracksTime)

        task.trackingOverride = false
        #expect(!task.tracksTime)

        work.tracksTimeByDefault = false
        task.trackingOverride = true
        #expect(task.tracksTime)
    }

    @Test func taskWithoutCategoryIsNotTrackedByDefault() {
        #expect(!fixture.task().tracksTime)
    }

    @Test func overrideCountIgnoresOverridesEqualToDefault() {
        let work = fixture.list("Работа")
        work.tracksTimeByDefault = true
        fixture.task("A", list: work).trackingOverride = false
        fixture.task("B", list: work).trackingOverride = true
        fixture.task("C", list: work)
        #expect(work.trackingOverrideCount == 1)
    }

    @Test func estimateFallsBackToSingleDaySlot() {
        let timed = fixture.task(due: "2026-11-08 10:00", minutes: 90)
        #expect(timed.effectiveEstimate == 90)

        let allDay = fixture.task(due: "2026-11-08")
        #expect(allDay.effectiveEstimate == nil)

        let multiDay = fixture.task(due: "2026-11-08 10:00", minutes: 90, endDay: "2026-11-10")
        #expect(multiDay.effectiveEstimate == nil)

        #expect(fixture.task().effectiveEstimate == nil)
    }

    @Test func explicitEstimateWinsAndZeroMeansNone() {
        let task = fixture.task(due: "2026-11-08 10:00", minutes: 90)
        task.estimateMinutes = 150
        #expect(task.effectiveEstimate == 150)
        task.estimateMinutes = 0
        #expect(task.effectiveEstimate == nil)
    }

    @Test func trackedMinutesSumOnlyWork() {
        let task = fixture.task()
        _ = entry("2026-11-08 09:00", "2026-11-08 09:25", task: task)
        _ = entry("2026-11-08 09:30", "2026-11-08 09:47", status: .interrupted, task: task)
        _ = entry("2026-11-08 10:00", "2026-11-08 10:25", status: .cancelled, task: task)
        _ = entry("2026-11-08 11:00", "2026-11-08 11:20", kind: .manual, task: task)
        _ = entry("2026-11-08 09:00", "2026-11-08 10:00")
        #expect(task.trackedMinutes == 25 + 17 + 20)
    }

    // MARK: - Настройки фокуса

    @Test func focusSettingsDefaultsMatchDesign() {
        let settings = FocusSettings()
        #expect(settings.preset == .classic)
        #expect(settings.focusMinutes == 25)
        #expect(settings.shortBreakMinutes == 5)
        #expect(settings.longBreakMinutes == 15)
        #expect(settings.longBreakEvery == 4)
        #expect(settings.autoStartBreaks)
        #expect(!settings.autoStartFocus)
        #expect(settings.sessionNotifications)
    }

    @Test func applyingPresetSetsDurations() {
        var settings = FocusSettings()
        settings.apply(.extended)
        #expect((settings.focusMinutes, settings.shortBreakMinutes, settings.longBreakMinutes) == (50, 10, 30))

        settings.focusMinutes = 40
        settings.apply(.custom)
        #expect(settings.preset == .custom)
        #expect(settings.focusMinutes == 40)

        settings.apply(.classic)
        #expect((settings.focusMinutes, settings.shortBreakMinutes, settings.longBreakMinutes) == (25, 5, 15))
    }

    @Test func oldSettingsWithoutFocusDecodeToDefaults() throws {
        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"firstWeekday": 1}"#.utf8))
        #expect(decoded.firstWeekday == 1)
        #expect(decoded.focus == FocusSettings())
    }

    @Test func partialFocusSettingsKeepOtherDefaults() throws {
        let json = #"{"focus": {"focusMinutes": 45, "autoStartFocus": true}}"#
        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        #expect(decoded.focus.focusMinutes == 45)
        #expect(decoded.focus.autoStartFocus)
        #expect(decoded.focus.shortBreakMinutes == 5)
    }

    @Test func focusSettingsRoundTrip() throws {
        var settings = AppSettings()
        settings.focus.apply(.extended)
        settings.focus.longBreakEvery = 3
        settings.focus.sessionNotifications = false
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
    }
}
