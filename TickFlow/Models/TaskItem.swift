import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var isCompleted: Bool = false
    var completedAt: Date?
    /// Дата выполнения. Если `hasTime == false`, хранится начало дня.
    var dueDate: Date?
    var hasTime: Bool = false
    /// Длительность в минутах. Имеет смысл только при `hasTime == true`.
    var durationMinutes: Int = 60
    var priorityRaw: Int = 0
    /// Последний день многодневной задачи (начало дня). `nil` — задача на один день.
    var endDay: Date?
    /// `ReminderOption`. По умолчанию «в момент начала» — так работали старые задачи.
    var reminderRaw: Int = 1
    /// `RepeatRule`.
    var repeatRaw: Int = 0
    var sortOrder: Int = 0
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    /// Трекинг времени для этой задачи. `nil` — как у категории.
    var trackingOverride: Bool?
    /// Оценка в минутах. `nil` — берётся длительность слота, `0` — оценки нет.
    var estimateMinutes: Int?

    var list: TaskList?

    @Relationship(deleteRule: .cascade, inverse: \Subtask.parent)
    var subtasks: [Subtask] = []

    /// История остаётся после удаления задачи — записи просто теряют связь.
    @Relationship(deleteRule: .nullify, inverse: \TimeEntry.task)
    var timeEntries: [TimeEntry] = []

    init(
        title: String,
        notes: String = "",
        dueDate: Date? = nil,
        hasTime: Bool = false,
        durationMinutes: Int = 60,
        priority: Priority = .none,
        list: TaskList? = nil,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.hasTime = hasTime
        self.durationMinutes = durationMinutes
        self.priorityRaw = priority.rawValue
        self.list = list
        self.sortOrder = sortOrder
        self.createdAt = .now
        self.updatedAt = .now
    }

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue }
    }

    var reminder: ReminderOption {
        get { ReminderOption(rawValue: reminderRaw) ?? .none }
        set { reminderRaw = newValue.rawValue }
    }

    var repeatRule: RepeatRule {
        get { RepeatRule(rawValue: repeatRaw) ?? .never }
        set { repeatRaw = newValue.rawValue }
    }

    var isMultiDay: Bool { isMultiDay(calendar: .current) }

    func isMultiDay(calendar: Calendar) -> Bool {
        guard let dueDate, let endDay else { return false }
        return !calendar.isDate(dueDate, inSameDayAs: endDay)
    }

    /// Последний день задачи: `endDay` для многодневной, иначе день `dueDate`.
    var lastDay: Date? { lastDay(calendar: .current) }

    func lastDay(calendar: Calendar) -> Date? {
        guard let dueDate else { return nil }
        return calendar.startOfDay(for: endDay ?? dueDate)
    }

    /// Попадает ли задача на день (учитывая многодневные).
    func occurs(on day: Date, calendar: Calendar = .current) -> Bool {
        guard let dueDate, let lastDay = lastDay(calendar: calendar) else { return false }
        let target = calendar.startOfDay(for: day)
        return calendar.startOfDay(for: dueDate) <= target && target <= lastDay
    }

    var sortedSubtasks: [Subtask] {
        subtasks.sorted { $0.sortOrder < $1.sortOrder }
    }

    var endDate: Date? {
        guard let dueDate, hasTime else { return nil }
        return dueDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }

    /// Просрочена: последний день задачи уже прошёл. Сегодняшние задачи не считаются просроченными.
    var isOverdue: Bool { isOverdue(now: .now, calendar: .current) }

    func isOverdue(now: Date, calendar: Calendar) -> Bool {
        guard !isCompleted, let lastDay = lastDay(calendar: calendar) else { return false }
        return lastDay < calendar.startOfDay(for: now)
    }

    /// Момент срабатывания напоминания: только для задач со временем и выбранным напоминанием.
    var reminderDate: Date? { reminderDate(now: .now) }

    func reminderDate(now: Date) -> Date? {
        guard let dueDate, hasTime, !isCompleted, let offset = reminder.offset else { return nil }
        let fire = dueDate.addingTimeInterval(offset)
        return fire > now ? fire : nil
    }

    // MARK: - Трекинг времени

    /// Показывать ли трекинг: своя настройка задачи важнее настройки категории.
    var tracksTime: Bool {
        trackingOverride ?? list?.tracksTimeByDefault ?? false
    }

    /// Оценка в минутах. Без своей оценки — длительность запланированного слота на один день.
    var effectiveEstimate: Int? {
        if let estimateMinutes { return estimateMinutes > 0 ? estimateMinutes : nil }
        guard dueDate != nil, hasTime, endDay == nil else { return nil }
        return durationMinutes
    }

    /// Потрачено минут: без перерывов и отброшенных сессий.
    var trackedMinutes: Int {
        timeEntries.filter(\.countsAsWork).reduce(0) { $0 + $1.durationMinutes }
    }

    var completedSubtaskCount: Int {
        subtasks.filter(\.isCompleted).count
    }

    func setCompleted(_ value: Bool, at now: Date = .now) {
        isCompleted = value
        completedAt = value ? now : nil
    }

    /// Переносит на сегодня, сохраняя время, если оно указано.
    func moveToToday(calendar: Calendar = .current, now: Date = .now) {
        if hasTime, let dueDate {
            let components = calendar.dateComponents([.hour, .minute], from: dueDate)
            self.dueDate = calendar.date(
                bySettingHour: components.hour ?? 9,
                minute: components.minute ?? 0,
                second: 0,
                of: now
            )
        } else {
            dueDate = calendar.startOfDay(for: now)
        }
        endDay = nil
    }
}
