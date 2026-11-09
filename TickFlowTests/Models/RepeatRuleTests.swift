import Foundation
import Testing
@testable import TickFlow

struct RepeatRuleTests {
    let calendar = TestCalendar.moscow

    private func next(_ rule: RepeatRule, after string: String, calendar: Calendar = TestCalendar.moscow) -> Date? {
        rule.nextDate(after: date(string, calendar: calendar), calendar: calendar)
    }

    @Test func neverHasNoNextDate() {
        #expect(next(.never, after: "2026-11-08 09:00") == nil)
    }

    @Test(arguments: [
        ("2026-11-08 09:00", "2026-11-09 09:00"),
        ("2026-01-31 09:00", "2026-02-01 09:00"),
        ("2026-12-31 23:30", "2027-01-01 23:30"),
        ("2028-02-28 10:00", "2028-02-29 10:00"),
    ])
    func dailyAddsOneDay(from: String, expected: String) {
        #expect(next(.daily, after: from) == date(expected))
    }

    @Test func weeklyAddsSevenDays() {
        #expect(next(.weekly, after: "2026-11-08 09:00") == date("2026-11-15 09:00"))
        #expect(next(.weekly, after: "2026-12-28 09:00") == date("2027-01-04 09:00"))
    }

    @Test(arguments: [
        ("2026-11-08 09:00", "2026-12-08 09:00"),
        ("2026-01-31 09:00", "2026-02-28 09:00"),
        ("2028-01-31 09:00", "2028-02-29 09:00"),
        ("2026-12-15 09:00", "2027-01-15 09:00"),
    ])
    func monthlyClampsToEndOfMonth(from: String, expected: String) {
        #expect(next(.monthly, after: from) == date(expected))
    }

    /// Текущее поведение: после переноса на 28 февраля серия продолжается от 28-го, а не от 31-го.
    @Test func monthlyDriftsAfterShortMonth() {
        let february = next(.monthly, after: "2026-01-31 09:00")!
        #expect(RepeatRule.monthly.nextDate(after: february, calendar: calendar) == date("2026-03-28 09:00"))
    }

    @Test(arguments: [
        ("2026-11-06 09:00", "2026-11-09 09:00"), // пт → пн
        ("2026-11-07 09:00", "2026-11-09 09:00"), // сб → пн
        ("2026-11-08 09:00", "2026-11-09 09:00"), // вс → пн
        ("2026-11-09 09:00", "2026-11-10 09:00"), // пн → вт
        ("2026-11-12 18:00", "2026-11-13 18:00"), // чт → пт
    ])
    func weekdaysSkipsWeekend(from: String, expected: String) {
        #expect(next(.weekdays, after: from) == date(expected))
    }

    @Test func keepsTimeOfDayAcrossDaylightSavingChange() {
        let berlin = TestCalendar.berlin
        // 29.03.2026 в Берлине переход на летнее время, сутки короче на час.
        #expect(next(.daily, after: "2026-03-28 09:00", calendar: berlin) == date("2026-03-29 09:00", calendar: berlin))
        #expect(next(.weekly, after: "2026-03-25 09:00", calendar: berlin) == date("2026-04-01 09:00", calendar: berlin))
        // 25.10.2026 — обратный переход, сутки длиннее на час.
        #expect(next(.daily, after: "2026-10-24 09:00", calendar: berlin) == date("2026-10-25 09:00", calendar: berlin))
    }
}
