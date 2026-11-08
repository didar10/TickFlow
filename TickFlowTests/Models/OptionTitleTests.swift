import Foundation
import Testing
@testable import TickFlow

/// У каждого варианта есть своя подпись: пустая или повторяющаяся строка в пикере — ошибка перевода.
@MainActor
struct OptionTitleTests {
    private func expectDistinct(_ titles: [String], sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(!titles.contains(""), sourceLocation: sourceLocation)
        #expect(Set(titles).count == titles.count, "Повторяются: \(titles)", sourceLocation: sourceLocation)
    }

    @Test func taskOptions() {
        expectDistinct(ReminderOption.allCases.map(\.title))
        expectDistinct(RepeatRule.allCases.map(\.title))
        expectDistinct(Priority.allCases.map(\.title))
        #expect(ReminderOption.allCases.map(\.id) == [0, 1, 2, 3])
        #expect(RepeatRule.allCases.map(\.id) == [0, 1, 2, 3, 4])
    }

    @Test func habitOptions() {
        expectDistinct(HabitKind.allCases.map(\.title))
        expectDistinct(HabitFrequency.allCases.map(\.title))
        #expect(HabitKind.allCases.map(\.id) == HabitKind.allCases.map(\.rawValue))
        #expect(HabitFrequency.allCases.map(\.id) == HabitFrequency.allCases.map(\.rawValue))
    }

    @Test func appOptions() {
        expectDistinct(AppTheme.allCases.map(\.title))
        expectDistinct(CalendarMode.allCases.map(\.title))
        expectDistinct(CalendarMode.allCases.map(\.symbolName))
        expectDistinct(TaskFilterStore.Status.allCases.map(\.title))
        #expect(AppTheme.allCases.map(\.id) == [0, 1, 2])
        #expect(CalendarMode.allCases.map(\.dayCount) == [1, 1, 3, 7])
    }

    @Test func habitDayStateLabels() {
        let states: [HabitDayState] = [.done, .skipped, .missed, .rest, .planned, .today, .notStarted]
        expectDistinct(states.map(\.label))
    }

    @Test func systemClockIsCurrentTime() {
        let before = Date.now
        let now = SystemClock().now
        #expect(now >= before && now <= Date.now)
    }
}
