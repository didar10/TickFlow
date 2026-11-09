import Foundation
import Testing
@testable import TickFlow

/// Сегодня во всех тестах — воскресенье 08.11.2026.
@MainActor
struct HabitHistoryTests {
    let fixture: ModelFixture
    let today = date("2026-11-08 15:00")

    init() throws {
        fixture = try ModelFixture()
    }

    private func history(
        _ habit: Habit,
        keepStreak: Bool = true,
        calendar: Calendar = TestCalendar.moscow
    ) -> HabitHistory {
        HabitHistory(habit: habit, calendar: calendar, today: today, skippedKeepStreak: keepStreak)
    }

    // MARK: - Состояние дня

    @Test func dailyHabitStates() {
        let habit = fixture.habit(start: "2026-11-01")
        fixture.log(habit, "2026-11-05")
        fixture.log(habit, "2026-11-06", skipped: true)
        let history = history(habit)

        #expect(history.state(on: date("2026-10-31")) == .notStarted)
        #expect(history.state(on: date("2026-11-04")) == .missed)
        #expect(history.state(on: date("2026-11-05 22:00")) == .done)
        #expect(history.state(on: date("2026-11-06")) == .skipped)
        #expect(history.state(on: date("2026-11-08")) == .today)
        #expect(history.state(on: date("2026-11-09")) == .planned)
    }

    @Test func doneTodayIsDoneNotToday() {
        let habit = fixture.habit()
        fixture.log(habit, "2026-11-08")
        #expect(history(habit).state(on: today) == .done)
    }

    @Test func specificDaysHabitRestsOnOtherDays() {
        // пн, ср, пт; сегодня воскресенье.
        let habit = fixture.habit(frequency: .specificDays, weekdays: [2, 4, 6])
        let history = history(habit)

        #expect(history.state(on: date("2026-11-08")) == .rest)
        #expect(history.state(on: date("2026-11-03")) == .rest) // вт
        #expect(history.state(on: date("2026-11-04")) == .missed) // ср
        #expect(history.state(on: date("2026-11-09")) == .planned) // пн
        #expect(history.state(on: date("2026-11-10")) == .rest) // вт
    }

    @Test func weeklyGoalHasNoMissedDays() {
        let habit = fixture.habit(frequency: .weeklyGoal, timesPerWeek: 3)
        let history = history(habit)

        #expect(history.state(on: date("2026-11-04")) == .rest)
        #expect(history.state(on: date("2026-11-08")) == .today)
        #expect(history.state(on: date("2026-11-09")) == .rest)
    }

    @Test func amountHabitIsDoneOnlyAtTarget() {
        let habit = fixture.habit(kind: .amount, target: 2000, unit: "мл")
        fixture.log(habit, "2026-11-05", value: 1000)
        fixture.log(habit, "2026-11-06", value: 2000)
        fixture.log(habit, "2026-11-07", value: 2500)
        let history = history(habit)

        #expect(history.value(on: date("2026-11-05")) == 1000)
        #expect(!history.isDone(on: date("2026-11-05")))
        #expect(history.state(on: date("2026-11-05")) == .missed)
        #expect(history.isDone(on: date("2026-11-06")))
        #expect(history.isDone(on: date("2026-11-07")))
        #expect(history.value(on: date("2026-11-04")) == 0)
    }

    // MARK: - Процент

    @Test func completionCountsDoneAndMissedOnly() {
        let habit = fixture.habit(start: "2026-11-01")
        fixture.done(habit, "2026-11-02", "2026-11-03")
        fixture.log(habit, "2026-11-04", skipped: true)
        let history = history(habit)

        // До старта — не считается; пропуск — не считается; сегодня ещё не отмечено — не считается.
        let result = history.completion(from: date("2026-10-25"), to: date("2026-11-08"))
        #expect(result.done == 2)
        #expect(result.counted == 6) // 01, 02, 03, 05, 06, 07
    }

    @Test func completionIgnoresFutureDays() {
        let habit = fixture.habit(start: "2026-11-01")
        fixture.done(habit, "2026-11-08")
        let result = history(habit).completion(from: date("2026-11-08"), to: date("2026-11-30"))
        #expect(result.done == 1)
        #expect(result.counted == 1)
    }

    // MARK: - Серии (ежедневно)

    @Test func dailyStreakIsNotBrokenByUnmarkedToday() {
        let habit = fixture.habit(start: "2026-11-01")
        fixture.done(habit, "2026-11-05", "2026-11-06", "2026-11-07")
        let stats = history(habit).stats

        #expect(stats.current == 3)
        #expect(stats.best == 3)
        #expect(stats.total == 3)
        #expect(!stats.isWeekly)
        // За 30 дней: 01–07 учтены (3 выполнено из 7), сегодня не учитывается.
        #expect(stats.rate == 43)
    }

    @Test func dailyStreakIncludesToday() {
        let habit = fixture.habit(start: "2026-11-01")
        fixture.done(habit, "2026-11-06", "2026-11-07", "2026-11-08")
        #expect(history(habit).stats.current == 3)
    }

    @Test func missedDayBreaksStreakButKeepsBest() {
        let habit = fixture.habit(start: "2026-11-01")
        fixture.done(habit, "2026-11-01", "2026-11-02", "2026-11-03", "2026-11-04", "2026-11-07")
        let stats = history(habit).stats

        #expect(stats.current == 1)
        #expect(stats.best == 4)
    }

    @Test func skippedDayKeepsStreakWhenEnabled() {
        let habit = fixture.habit(start: "2026-11-01")
        fixture.done(habit, "2026-11-05", "2026-11-07")
        fixture.log(habit, "2026-11-06", skipped: true)
        let stats = history(habit, keepStreak: true).stats

        // Пропуск не прерывает серию, но и не увеличивает её.
        #expect(stats.current == 2)
        #expect(stats.best == 2)
    }

    @Test func skippedDayBreaksStreakWhenDisabled() {
        let habit = fixture.habit(start: "2026-11-01")
        fixture.done(habit, "2026-11-05", "2026-11-07")
        fixture.log(habit, "2026-11-06", skipped: true)
        let stats = history(habit, keepStreak: false).stats

        #expect(stats.current == 1)
        #expect(stats.best == 1)
    }

    @Test func unscheduledDaysDoNotBreakStreak() {
        // пн, ср, пт.
        let habit = fixture.habit(frequency: .specificDays, weekdays: [2, 4, 6], start: "2026-11-01")
        fixture.done(habit, "2026-11-02", "2026-11-04", "2026-11-06")
        let stats = history(habit).stats

        #expect(stats.current == 3)
        #expect(stats.rate == 100)
    }

    @Test func newHabitHasEmptyStats() {
        let habit = fixture.habit(start: "2026-11-08")
        let stats = history(habit).stats
        #expect(stats.current == 0)
        #expect(stats.best == 0)
        #expect(stats.rate == 0)
        #expect(stats.total == 0)
    }

    @Test func partialAmountIsNotCountedInTotal() {
        let habit = fixture.habit(kind: .amount, target: 10, start: "2026-11-01")
        fixture.log(habit, "2026-11-06", value: 5)
        fixture.log(habit, "2026-11-07", value: 10)
        let stats = history(habit).stats
        #expect(stats.total == 1)
        #expect(stats.current == 1)
    }

    // MARK: - Серии (недельная цель)

    @Test func weeklyStreakCountsWeeksWithGoalReached() {
        let habit = fixture.habit(frequency: .weeklyGoal, timesPerWeek: 2, start: "2026-10-19")
        // Недели с понедельника: 19.10, 26.10, 02.11 — в каждой по две отметки.
        fixture.done(habit, "2026-10-20", "2026-10-22", "2026-10-27", "2026-10-29", "2026-11-03", "2026-11-05")
        let stats = history(habit).stats

        #expect(stats.isWeekly)
        #expect(stats.current == 3)
        #expect(stats.best == 3)
        #expect(stats.total == 6)
        // За 28 дней 6 отметок при цели 2 × 4 недели.
        #expect(stats.rate == 75)
    }

    @Test func unfinishedCurrentWeekDoesNotResetStreak() {
        let habit = fixture.habit(frequency: .weeklyGoal, timesPerWeek: 2, start: "2026-10-19")
        fixture.done(habit, "2026-10-27", "2026-10-29", "2026-11-03")
        let stats = history(habit).stats

        // Текущая неделя (одна отметка) не засчитана, но и не обнуляет прошлую.
        #expect(stats.current == 1)
        #expect(stats.best == 1)
    }

    @Test func weeklyStreakDependsOnFirstWeekday() {
        let habit = fixture.habit(frequency: .weeklyGoal, timesPerWeek: 2, start: "2026-10-19")
        // Вс 01.11 и вт 03.11: с понедельника — разные недели, с воскресенья — одна.
        fixture.done(habit, "2026-11-01", "2026-11-03")

        let mondayFirst = history(habit, calendar: TestCalendar.make(timeZone: "Europe/Moscow", firstWeekday: 2)).stats
        let sundayFirst = history(habit, calendar: TestCalendar.make(timeZone: "Europe/Moscow", firstWeekday: 1)).stats

        #expect(mondayFirst.current == 0)
        #expect(mondayFirst.best == 0)
        #expect(sundayFirst.current == 1)
        #expect(sundayFirst.best == 1)
    }

    @Test func weeklyRateIsCappedAt100() {
        let habit = fixture.habit(frequency: .weeklyGoal, timesPerWeek: 1, start: "2026-10-19")
        fixture.done(habit, "2026-11-01", "2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05")
        #expect(history(habit).stats.rate == 100)
    }
}
