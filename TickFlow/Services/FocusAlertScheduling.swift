import Foundation
import UserNotifications

/// Уведомление о конце фазы фокуса. Одно на всё приложение: новая фаза заменяет старое.
@MainActor
protocol FocusAlertScheduling {
    func schedule(title: String, body: String, at date: Date)
    func cancel()
}

/// Через `UNUserNotificationCenter`. Без разрешения уведомление не ставится.
struct SystemFocusAlertScheduler: FocusAlertScheduling {
    static let identifier = "focus-phase-end"

    func schedule(title: String, body: String, at date: Date) {
        cancel()
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: Self.identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
        Task {
            guard await NotificationScheduler.isAuthorized() else { return }
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }
}
