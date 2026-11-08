import Foundation

/// Локальные напоминания задач и привычек. Репозитории и экраны работают через протокол,
/// чтобы в тестах подменять `UNUserNotificationCenter` фейком.
@MainActor
protocol ReminderScheduling {
    /// Запрашивает разрешение, если оно ещё не выдано. Возвращает, разрешены ли уведомления.
    func requestAuthorization() async -> Bool
    /// Разрешены ли уведомления, без показа системного запроса.
    func isAuthorized() async -> Bool
    /// Пользователь запретил уведомления.
    func isDenied() async -> Bool

    /// Снимает старое напоминание задачи и ставит новое, если дата в будущем.
    func reschedule(taskID: UUID, title: String, fireDate: Date?)
    func cancel(taskID: UUID)

    /// Повторяющееся напоминание привычки: каждый день или в выбранные дни недели (1 — воскресенье).
    func scheduleHabit(id: UUID, name: String, minute: Int, weekdays: [Int]?)
    func cancelHabit(id: UUID)
}

/// Напоминания через `UNUserNotificationCenter`.
struct SystemReminderScheduler: ReminderScheduling {
    func requestAuthorization() async -> Bool { await NotificationScheduler.requestAuthorization() }
    func isAuthorized() async -> Bool { await NotificationScheduler.isAuthorized() }
    func isDenied() async -> Bool { await NotificationScheduler.isDenied() }

    func reschedule(taskID: UUID, title: String, fireDate: Date?) {
        NotificationScheduler.reschedule(id: taskID, title: title, fireDate: fireDate)
    }

    func cancel(taskID: UUID) { NotificationScheduler.cancel(taskID: taskID) }

    func scheduleHabit(id: UUID, name: String, minute: Int, weekdays: [Int]?) {
        NotificationScheduler.scheduleHabit(id: id, name: name, minute: minute, weekdays: weekdays)
    }

    func cancelHabit(id: UUID) { NotificationScheduler.cancelHabit(id: id) }
}
