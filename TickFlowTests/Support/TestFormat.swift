import Foundation
@testable import TickFlow

/// Форматтер, как во ViewModel, но с фиксированными календарём (Москва), часами и русской локалью.
func makeFormat(
    clock: any AppClock = FixedClock("2026-11-08 09:00"),
    settings: AppSettings = AppSettings(),
    calendar: Calendar = TestCalendar.moscow
) -> DisplayFormatter {
    DisplayFormatter(settings: settings, base: calendar, clock: clock, locale: Locale(identifier: "ru_RU"))
}
