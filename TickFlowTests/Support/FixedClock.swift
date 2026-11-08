import Foundation
@testable import TickFlow

/// Часы, которые показывают заданное время, пока тест сам его не сдвинет.
/// Каждый тест создаёт свой экземпляр, поэтому `@unchecked Sendable` безопасен.
final class FixedClock: AppClock, @unchecked Sendable {
    var now: Date

    init(_ now: Date) {
        self.now = now
    }

    convenience init(_ string: String, calendar: Calendar = TestCalendar.moscow) {
        self.init(date(string, calendar: calendar))
    }

    func advance(minutes: Int) {
        now = now.addingTimeInterval(TimeInterval(minutes * 60))
    }

    func advance(days: Int, calendar: Calendar = TestCalendar.moscow) {
        now = calendar.date(byAdding: .day, value: days, to: now)!
    }
}
