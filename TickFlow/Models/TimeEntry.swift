import Foundation
import SwiftData

/// Откуда взялась запись времени.
enum TimeEntryKind: Int, CaseIterable, Codable {
    /// Сессия фокуса (Pomodoro).
    case focus = 0
    /// Секундомер на задаче.
    case timer = 1
    /// Добавлена вручную.
    case manual = 2
    /// Перерыв между сессиями фокуса. Не считается временем задачи.
    case breakTime = 3
}

/// Чем закончилась сессия.
enum TimeEntryStatus: Int, CaseIterable, Codable {
    case completed = 0
    /// Остановлена раньше времени, но сохранена.
    case interrupted = 1
    /// Отброшена. Остаётся в истории, но не входит в итоги.
    case cancelled = 2
}

/// Отрезок потраченного времени. Связь с задачей необязательна:
/// фокус можно запустить без задачи, а при удалении задачи история остаётся.
@Model
final class TimeEntry {
    var id: UUID = UUID()
    var start: Date = Date.now
    var end: Date = Date.now
    var kindRaw: Int = 0
    var statusRaw: Int = 0
    var createdAt: Date = Date.now

    var task: TaskItem?

    init(
        start: Date,
        end: Date,
        kind: TimeEntryKind,
        status: TimeEntryStatus = .completed,
        task: TaskItem? = nil
    ) {
        self.id = UUID()
        self.start = start
        self.end = end
        self.kindRaw = kind.rawValue
        self.statusRaw = status.rawValue
        self.task = task
        self.createdAt = .now
    }

    var kind: TimeEntryKind {
        get { TimeEntryKind(rawValue: kindRaw) ?? .focus }
        set { kindRaw = newValue.rawValue }
    }

    var status: TimeEntryStatus {
        get { TimeEntryStatus(rawValue: statusRaw) ?? .completed }
        set { statusRaw = newValue.rawValue }
    }

    /// Длительность в целых минутах.
    var durationMinutes: Int {
        max(0, Int((end.timeIntervalSince(start) / 60).rounded()))
    }

    /// Работа, а не перерыв и не отброшенная сессия: входит в итоги задачи и аналитику.
    var countsAsWork: Bool {
        kind != .breakTime && status != .cancelled
    }
}
