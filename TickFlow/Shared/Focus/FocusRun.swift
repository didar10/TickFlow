import Foundation

/// Текущая сессия фокуса или таймера. Время считается по меткам, а не тиками:
/// пока сессия идёт, `resumedAt` хранит момент последнего запуска, а прошедшее время до него —
/// в `accumulated`. Поэтому сессия переживает уход приложения в фон и перезапуск.
struct FocusRun: Codable, Equatable {
    enum Mode: Int, Codable {
        /// Pomodoro: фаза идёт до конца отведённого времени.
        case focus = 0
        /// Секундомер на задаче без ограничения.
        case timer = 1
    }

    enum Phase: Int, Codable {
        case focus = 0
        case shortBreak = 1
        case longBreak = 2

        var isBreak: Bool { self != .focus }
    }

    var mode: Mode
    var taskID: UUID?
    var phase: Phase
    /// Секунды, набранные до последнего запуска.
    var accumulated: TimeInterval = 0
    /// Момент последнего запуска. `nil` — на паузе или ещё не запущена.
    var resumedAt: Date?
    /// Длина фазы в секундах. У таймера нет.
    var total: TimeInterval?
    /// Сколько сессий фокуса завершено в текущем цикле.
    var round = 0
    var pauseCount = 0
    /// Цикл начат: мини-плеер виден, даже если фаза ждёт запуска.
    /// Фокус, открытый без запуска, ещё не активен.
    var isActive: Bool

    init(mode: Mode, taskID: UUID?, phase: Phase = .focus, total: TimeInterval?, round: Int = 0, isActive: Bool) {
        self.mode = mode
        self.taskID = taskID
        self.phase = phase
        self.total = total
        self.round = round
        self.isActive = isActive
    }

    var isRunning: Bool { resumedAt != nil }
    /// Фаза ещё не начиналась: ни секунды не набрано.
    var isReady: Bool { resumedAt == nil && accumulated == 0 }

    func elapsed(at now: Date) -> TimeInterval {
        accumulated + (resumedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    /// Осталось до конца фазы. У таймера — `nil`.
    func remaining(at now: Date) -> TimeInterval? {
        total.map { max(0, $0 - elapsed(at: now)) }
    }

    /// Момент, когда фаза закончится, если не ставить на паузу.
    var endsAt: Date? {
        guard let resumedAt, let total else { return nil }
        return resumedAt.addingTimeInterval(total - accumulated)
    }

    /// Доля пройденной фазы, 0…1. Для таймера без оценки — круг в час.
    func progress(at now: Date, estimateSeconds: TimeInterval? = nil, alreadyTracked: TimeInterval = 0) -> Double {
        let elapsed = elapsed(at: now)
        if let total, total > 0 { return min(1, elapsed / total) }
        if let estimateSeconds, estimateSeconds > 0 { return min(1, (alreadyTracked + elapsed) / estimateSeconds) }
        return elapsed.truncatingRemainder(dividingBy: 3600) / 3600
    }

    /// Тип записи, которой станет фаза.
    var entryKind: TimeEntryKind {
        if phase.isBreak { return .breakTime }
        return mode == .timer ? .timer : .focus
    }

    /// Идёт работа над задачей (не перерыв) и уже набрано время.
    func isTrackingWork(at now: Date) -> Bool {
        isActive && !phase.isBreak && elapsed(at: now) > 0
    }

    mutating func pause(at now: Date) {
        guard let resumedAt else { return }
        accumulated += max(0, now.timeIntervalSince(resumedAt))
        self.resumedAt = nil
        pauseCount += 1
    }

    mutating func resume(at now: Date) {
        guard resumedAt == nil else { return }
        resumedAt = now
        isActive = true
    }
}

extension FocusRun {
    /// Обратный отсчёт фокуса «24:59» или время таймера «1:02:03».
    func clockText(at now: Date) -> String {
        if mode == .timer { return Self.stopwatch(elapsed(at: now)) }
        return Self.countdown(remaining(at: now) ?? 0)
    }

    /// «24:59»: минуты без ограничения, секунды округляются вверх, чтобы 0:00 было только в конце.
    static func countdown(_ seconds: TimeInterval) -> String {
        let value = Int(max(0, seconds).rounded(.up))
        return "\(value / 60):" + String(format: "%02d", value % 60)
    }

    /// «12:05» или «1:02:03».
    static func stopwatch(_ seconds: TimeInterval) -> String {
        let value = Int(max(0, seconds))
        let h = value / 3600, m = value % 3600 / 60, s = value % 60
        return h > 0 ? "\(h):" + String(format: "%02d:%02d", m, s) : "\(m):" + String(format: "%02d", s)
    }
}
