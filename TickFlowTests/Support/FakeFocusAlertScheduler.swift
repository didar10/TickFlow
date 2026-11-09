import Foundation
@testable import TickFlow

/// Запоминает уведомления о конце фазы вместо `UNUserNotificationCenter`.
@MainActor
final class FakeFocusAlertScheduler: FocusAlertScheduling {
    struct Alert: Equatable {
        let title: String
        let body: String
        let date: Date
    }

    /// Поставленное сейчас уведомление. `nil` — снято.
    private(set) var pending: Alert?
    private(set) var scheduleCount = 0

    func schedule(title: String, body: String, at date: Date) {
        pending = Alert(title: title, body: body, date: date)
        scheduleCount += 1
    }

    func cancel() {
        pending = nil
    }
}
