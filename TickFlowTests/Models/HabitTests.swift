import Foundation
import Testing
@testable import TickFlow

@MainActor
struct HabitTests {
    let fixture: ModelFixture
    let calendar = TestCalendar.moscow

    init() throws {
        fixture = try ModelFixture()
    }

    @Test func dailyAndWeeklyGoalAreScheduledEveryDay() {
        let daily = fixture.habit(frequency: .daily, weekdays: [2])
        let weekly = fixture.habit(frequency: .weeklyGoal, weekdays: [2])
        for day in ["2026-11-08", "2026-11-09", "2026-11-14"] {
            #expect(daily.isScheduled(on: date(day), calendar: calendar))
            #expect(weekly.isScheduled(on: date(day), calendar: calendar))
        }
    }

    @Test func specificDaysFollowWeekdays() {
        // 2 — пн, 4 — ср, 6 — пт.
        let habit = fixture.habit(frequency: .specificDays, weekdays: [2, 4, 6])
        #expect(habit.isScheduled(on: date("2026-11-09"), calendar: calendar)) // пн
        #expect(!habit.isScheduled(on: date("2026-11-10"), calendar: calendar)) // вт
        #expect(habit.isScheduled(on: date("2026-11-11 23:00"), calendar: calendar)) // ср
        #expect(habit.isScheduled(on: date("2026-11-13"), calendar: calendar)) // пт
        #expect(!habit.isScheduled(on: date("2026-11-08"), calendar: calendar)) // вс
    }

    @Test func logIsFoundByDayRegardlessOfTime() {
        let habit = fixture.habit()
        fixture.log(habit, "2026-11-08", value: 1)

        #expect(habit.log(on: date("2026-11-08 18:45"), calendar: calendar)?.value == 1)
        #expect(habit.log(on: date("2026-11-08 00:00"), calendar: calendar) != nil)
        #expect(habit.log(on: date("2026-11-09 00:00"), calendar: calendar) == nil)
        #expect(habit.log(on: date("2026-11-07 23:59"), calendar: calendar) == nil)
    }

    @Test func rawValuesFallBackToDefaults() {
        let habit = fixture.habit()
        habit.kindRaw = 99
        habit.frequencyRaw = 99
        #expect(habit.kind == .check)
        #expect(habit.frequency == .daily)
    }
}
