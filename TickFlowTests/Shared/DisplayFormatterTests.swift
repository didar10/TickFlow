import Foundation
import Testing
@testable import TickFlow

/// Тексты интерфейса — на русском (язык задан в схеме), локаль дат задаётся явно.
@MainActor
struct DisplayFormatterTests {
    let fixture: ModelFixture
    let clock = FixedClock("2026-11-08 15:00")

    init() throws {
        fixture = try ModelFixture()
    }

    private func format(uses24Hour: Bool = true, firstWeekday: Int = 2, locale: String = "ru_RU") -> DisplayFormatter {
        var settings = AppSettings()
        settings.uses24HourTime = uses24Hour
        settings.firstWeekday = firstWeekday
        return DisplayFormatter(settings: settings, base: TestCalendar.moscow, clock: clock, locale: Locale(identifier: locale))
    }

    // MARK: - Время

    @Test(arguments: [(0, "00:00"), (570, "09:30"), (780, "13:00"), (1439, "23:59"), (1440, "00:00")])
    func time24Hour(minute: Int, expected: String) {
        #expect(format().time(minute: minute) == expected)
    }

    @Test(arguments: [(0, "12:00 AM"), (570, "9:30 AM"), (720, "12:00 PM"), (780, "1:00 PM"), (1439, "11:59 PM")])
    func time12Hour(minute: Int, expected: String) {
        #expect(format(uses24Hour: false).time(minute: minute) == expected)
    }

    @Test func shortTimeHasNoMeridiem() {
        #expect(format(uses24Hour: false).shortTime(minute: 780) == "1:00")
        #expect(format(uses24Hour: false).shortTime(minute: 30) == "12:30")
        #expect(format().shortTime(minute: 780) == "13:00")
    }

    @Test func hourLabels() {
        #expect(format().hourLabel(9) == "09:00")
        #expect(format(uses24Hour: false).hourLabel(0) == "12 AM")
        #expect(format(uses24Hour: false).hourLabel(12) == "12 PM")
        #expect(format(uses24Hour: false).hourLabel(13) == "1 PM")
    }

    @Test func timeOfDate() {
        #expect(format().minute(of: date("2026-11-08 09:30")) == 570)
        #expect(format().time(date("2026-11-08 07:05")) == "07:05")
    }

    @Test(arguments: [(45, "45 мин"), (60, "1 ч"), (90, "1 ч 30 мин"), (120, "2 ч"), (0, "0 мин")])
    func duration(minutes: Int, expected: String) {
        #expect(format().duration(minutes: minutes) == expected)
    }

    // MARK: - Дни

    @Test func todayFollowsClock() {
        #expect(format().today == date("2026-11-08"))
        #expect(format().isToday(date("2026-11-08 23:59")))
        #expect(!format().isToday(date("2026-11-09 00:00")))
    }

    @Test func relativeDay() {
        let format = format()
        #expect(format.relativeDay(date("2026-11-07 10:00")) == "Вчера")
        #expect(format.relativeDay(date("2026-11-08 23:00")) == "Сегодня")
        #expect(format.relativeDay(date("2026-11-09 00:00")) == "Завтра")
        #expect(format.relativeDay(date("2026-11-12")) == format.weekdayAndDay(date("2026-11-12")))
        #expect(format.relativeDay(date("2026-11-12")).hasPrefix("Чт"))
    }

    @Test func dayFormats() {
        let format = format()
        #expect(format.dayMonth(date("2026-11-07")) == "7 нояб.")
        #expect(format.fullDay(date("2026-11-07")) == "Суббота, 7 ноября")
        #expect(format.shortRange(date("2026-11-07"), date("2026-11-09")) == "7 – 9 нояб.")
        #expect(format.shortRange(date("2026-10-30"), date("2026-11-02")) == "30 окт. – 2 нояб.")
    }

    @Test func monthTitleShowsYearOnlyWhenNotCurrent() {
        #expect(format().monthTitle(date("2026-03-01")) == "Март")
        #expect(format().monthTitle(date("2027-01-15")) == "Январь 2027")
        #expect(format().monthTitle(date("2025-12-01")) == "Декабрь 2025")
    }

    @Test func englishLocale() {
        let format = format(locale: "en_US")
        #expect(format.monthName(date("2026-03-01")) == "March")
        #expect(format.dayMonth(date("2026-11-07")) == "Nov 7")
    }

    @Test func weekdaySymbolsFollowFirstWeekday() {
        #expect(format(firstWeekday: 2).shortWeekdays.first == "Пн")
        #expect(format(firstWeekday: 2).shortWeekdays.last == "Вс")
        #expect(format(firstWeekday: 1).shortWeekdays.first == "Вс")
        #expect(format(firstWeekday: 2).veryShortWeekdays.count == 7)
        #expect(format(firstWeekday: 2).veryShortWeekdays.first == "П")
        #expect(format(firstWeekday: 1).veryShortWeekdays.first == "В")
    }

    // MARK: - Срок задачи

    @Test func dueLabels() {
        let format = format()
        #expect(format.dueLabel(for: fixture.task()) == "Без даты")
        #expect(format.dueLabel(for: fixture.task(due: "2026-11-08")) == "Сегодня")
        #expect(format.dueLabel(for: fixture.task(due: "2026-11-09 09:30")) == "Завтра, 09:30")
        #expect(format.dueLabel(for: fixture.task(due: "2026-11-07", endDay: "2026-11-09")) == "7 – 9 нояб.")
        #expect(format.dueLabel(for: fixture.task(due: "2026-10-30", endDay: "2026-11-02")) == "30 окт. – 2 нояб.")
    }

    @Test func dueLabelIn12HourFormat() {
        #expect(format(uses24Hour: false).dueLabel(for: fixture.task(due: "2026-11-08 18:15")) == "Сегодня, 6:15 PM")
    }

    @Test func capitalizedFirst() {
        #expect("пятница".capitalizedFirst == "Пятница")
        #expect("".capitalizedFirst == "")
        #expect("Уже".capitalizedFirst == "Уже")
    }
}
