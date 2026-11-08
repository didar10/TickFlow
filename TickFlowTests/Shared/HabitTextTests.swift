import Foundation
import Testing
@testable import TickFlow

/// Тесты запускаются на русском (язык задан в схеме).
@MainActor
struct HabitTextTests {
    let fixture: ModelFixture

    init() throws {
        fixture = try ModelFixture()
    }

    private func text(firstWeekday: Int = 2) -> HabitText {
        var settings = AppSettings()
        settings.firstWeekday = firstWeekday
        return HabitText(format: DisplayFormatter(
            settings: settings,
            base: TestCalendar.moscow,
            clock: FixedClock("2026-11-08 12:00"),
            locale: Locale(identifier: "ru_RU")
        ))
    }

    @Test(arguments: [(2.0, "2"), (1.5, "1,5"), (1.25, "1,25"), (0.333, "0,33"), (1500, "1500")])
    func valueUsesUpToTwoFractionDigits(value: Double, expected: String) {
        // Разделитель тысяч в ru — неразрывный пробел, его форма зависит от версии ICU.
        #expect(text().value(value).filter { !$0.isWhitespace } == expected)
    }

    @Test func unitForDurationIsMinutes() {
        #expect(text().unit(of: fixture.habit(kind: .duration, unit: "ignored")) == "мин")
        #expect(text().unit(of: fixture.habit(kind: .amount, unit: "мл")) == "мл")
    }

    @Test func scheduleDescriptions() {
        let text = text()
        #expect(text.schedule(of: fixture.habit(frequency: .daily)) == "Каждый день")
        #expect(text.schedule(of: fixture.habit(frequency: .specificDays, weekdays: [2, 3, 4, 5, 6])) == "По будням")
        #expect(text.schedule(of: fixture.habit(frequency: .specificDays, weekdays: [1, 2, 3, 4, 5, 6, 7])) == "Каждый день")
        #expect(text.schedule(of: fixture.habit(frequency: .specificDays, weekdays: [6, 2, 4])) == "Пн, Ср, Пт")
        #expect(text.schedule(of: fixture.habit(frequency: .weeklyGoal, timesPerWeek: 3)) == "3 раза в неделю")
        #expect(text.schedule(of: fixture.habit(frequency: .weeklyGoal, timesPerWeek: 5)) == "5 раз в неделю")
    }

    @Test func specificDaysFollowFirstWeekday() {
        let habit = fixture.habit(frequency: .specificDays, weekdays: [1, 2])
        #expect(text(firstWeekday: 2).schedule(of: habit) == "Пн, Вс")
        #expect(text(firstWeekday: 1).schedule(of: habit) == "Вс, Пн")
    }

    @Test func weekdayOrder() {
        #expect(text(firstWeekday: 2).weekdayOrder == [2, 3, 4, 5, 6, 7, 1])
        #expect(text(firstWeekday: 1).weekdayOrder == [1, 2, 3, 4, 5, 6, 7])
    }

    @Test func targetDescriptions() {
        #expect(text().target(of: fixture.habit(kind: .check)) == "Отметить выполнение")
        #expect(text().target(of: fixture.habit(kind: .duration, target: 20)) == "20 мин в день")
        #expect(text().target(of: fixture.habit(kind: .amount, target: 1.5, unit: "л")) == "1,5 л в день")
    }

    @Test(arguments: [(1, "1 день"), (2, "2 дня"), (5, "5 дней"), (11, "11 дней"), (21, "21 день"), (0, "0 дней")])
    func dailyStreakPluralization(count: Int, expected: String) {
        let stats = HabitStats(current: count, best: count, rate: 0, total: 0, isWeekly: false)
        #expect(text().streak(stats) == expected)
    }

    @Test func weeklyStreakAndExplicitCount() {
        let weekly = HabitStats(current: 3, best: 5, rate: 0, total: 0, isWeekly: true)
        #expect(text().streak(weekly) == "3 нед.")
        #expect(text().streak(weekly, count: weekly.best) == "5 нед.")
    }
}
