import Foundation
import UserNotifications

/// Локальные напоминания. Работает со значениями, а не с моделями SwiftData,
/// чтобы ничего не уезжало между акторами.
enum NotificationScheduler {

    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    /// Снимает старое напоминание и ставит новое, если дата в будущем.
    static func reschedule(id: UUID, title: String, fireDate: Date?) {
        cancel(taskID: id)
        guard let fireDate, fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Напоминание"
        content.body = title
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: id.uuidString,
            content: content,
            trigger: trigger
        )

        Task {
            _ = await requestAuthorization()
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    static func cancel(taskID: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [taskID.uuidString])
    }
}
