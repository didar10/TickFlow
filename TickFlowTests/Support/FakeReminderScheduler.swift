import Foundation
@testable import TickFlow

/// Запоминает вызовы вместо работы с `UNUserNotificationCenter`.
@MainActor
final class FakeReminderScheduler: ReminderScheduling {
    enum Call: Equatable {
        case requestAuthorization
        case reschedule(taskID: UUID, title: String, fireDate: Date?)
        case cancel(taskID: UUID)
        case scheduleHabit(id: UUID, name: String, minute: Int, weekdays: [Int]?)
        case cancelHabit(id: UUID)
    }

    /// Ответ на `requestAuthorization`.
    var grantsAuthorization = true
    var authorized = true
    var denied = false

    private(set) var calls: [Call] = []

    func requestAuthorization() async -> Bool {
        calls.append(.requestAuthorization)
        if grantsAuthorization { authorized = true }
        return grantsAuthorization
    }

    func isAuthorized() async -> Bool { authorized }
    func isDenied() async -> Bool { denied }

    func reschedule(taskID: UUID, title: String, fireDate: Date?) {
        calls.append(.reschedule(taskID: taskID, title: title, fireDate: fireDate))
    }

    func cancel(taskID: UUID) {
        calls.append(.cancel(taskID: taskID))
    }

    func scheduleHabit(id: UUID, name: String, minute: Int, weekdays: [Int]?) {
        calls.append(.scheduleHabit(id: id, name: name, minute: minute, weekdays: weekdays))
    }

    func cancelHabit(id: UUID) {
        calls.append(.cancelHabit(id: id))
    }

    /// Последняя дата напоминания, поставленная задаче (`nil` — снято или не ставилось).
    func lastFireDate(for taskID: UUID) -> Date? {
        for call in calls.reversed() {
            if case let .reschedule(id, _, fireDate) = call, id == taskID { return fireDate }
        }
        return nil
    }

    func reset() {
        calls.removeAll()
    }
}
