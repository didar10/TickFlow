import Foundation
import Testing
@testable import TickFlow

struct DateSelectionTests {
    let calendar = TestCalendar.moscow

    private func selection(
        day: String? = "2026-11-08",
        endDay: String = "2026-11-08",
        hasTime: Bool = true,
        start: Int = 600,
        end: Int = 660
    ) -> DateSelection {
        DateSelection(
            day: day.map { date($0) },
            endDay: date(endDay),
            hasTime: hasTime,
            startMinute: start,
            endMinute: end,
            reminder: .none,
            repeatRule: .never,
            isPeriod: false
        )
    }

    @Test func singleDay() {
        let value = selection()
        #expect(!value.isMultiDay(calendar: calendar))
        #expect(value.startDate(calendar: calendar) == date("2026-11-08 10:00"))
        #expect(value.endDate(calendar: calendar) == date("2026-11-08 11:00"))
        #expect(!value.isInvalid(calendar: calendar))
        #expect(value.durationMinutes == 60)
    }

    @Test func multiDayRange() {
        let value = selection(endDay: "2026-11-10", hasTime: false)
        #expect(value.isMultiDay(calendar: calendar))
        #expect(!value.isInvalid(calendar: calendar))
    }

    @Test func withoutDay() {
        let value = selection(day: nil)
        #expect(!value.isMultiDay(calendar: calendar))
        #expect(value.startDate(calendar: calendar) == nil)
        #expect(!value.isInvalid(calendar: calendar))
        #expect(value.durationMinutes == 60)
    }

    @Test func endMinute1440IsNextMidnight() {
        let value = selection(start: 1380, end: 1440)
        #expect(value.endDate(calendar: calendar) == date("2026-11-09 00:00"))
        #expect(!value.isInvalid(calendar: calendar))
        #expect(value.durationMinutes == 60)
    }

    @Test func throughMidnight() {
        let value = selection(endDay: "2026-11-09", start: 1380, end: 60)
        #expect(value.isMultiDay(calendar: calendar))
        #expect(!value.isInvalid(calendar: calendar))
        #expect(value.durationMinutes == 120)
    }

    @Test func endBeforeOrAtStartIsInvalid() {
        #expect(selection(start: 600, end: 600).isInvalid(calendar: calendar))
        #expect(selection(start: 600, end: 540).isInvalid(calendar: calendar))
        #expect(selection(day: "2026-11-08", endDay: "2026-11-07", hasTime: false).isInvalid(calendar: calendar))
    }

    @Test func untimedSameDayIgnoresMinutes() {
        #expect(!selection(hasTime: false, start: 600, end: 540).isInvalid(calendar: calendar))
    }

    @Test func durationHasFifteenMinuteFloor() {
        #expect(selection(start: 600, end: 605).durationMinutes == 15)
        #expect(selection(start: 600, end: 540).durationMinutes == 15)
        #expect(selection(start: 600, end: 690).durationMinutes == 90)
    }
}
