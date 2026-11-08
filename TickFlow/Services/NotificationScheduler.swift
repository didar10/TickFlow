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
        content.title = L10n.Common.reminder
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
            guard await isAuthorized() else { return }
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    static func cancel(taskID: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [taskID.uuidString])
    }

    // MARK: - Привычки

    /// Повторяющееся напоминание: каждый день или в выбранные дни недели (1 — воскресенье).
    static func scheduleHabit(id: UUID, name: String, minute: Int, weekdays: [Int]?) {
        cancelHabit(id: id)

        let content = UNMutableNotificationContent()
        content.title = name
        content.body = L10n.Habits.reminderBody(name)
        content.sound = .default

        let days: [Int?] = weekdays.map { $0.map(Optional.some) } ?? [nil]
        let requests = days.map { weekday in
            var components = DateComponents()
            components.hour = minute / 60
            components.minute = minute % 60
            components.weekday = weekday
            return UNNotificationRequest(
                identifier: habitIdentifier(id, weekday: weekday),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
        }

        Task {
            guard await isAuthorized() else { return }
            for request in requests {
                try? await UNUserNotificationCenter.current().add(request)
            }
        }
    }

    static func cancelHabit(id: UUID) {
        let identifiers = ([nil] + (1...7).map(Optional.some)).map { habitIdentifier(id, weekday: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Разрешены ли уведомления, без показа системного запроса.
    static func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return [.authorized, .provisional, .ephemeral].contains(status)
    }

    /// Пользователь запретил уведомления (в онбординге или в системных настройках).
    static func isDenied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    private static func habitIdentifier(_ id: UUID, weekday: Int?) -> String {
        "habit-\(id.uuidString)" + (weekday.map { "-\($0)" } ?? "")
    }
}
