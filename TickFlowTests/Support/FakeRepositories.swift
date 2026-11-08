import Foundation
@testable import TickFlow

/// Настройки в памяти. `updateCount` показывает, сколько раз экран их менял.
@MainActor
final class FakeSettingsRepository: SettingsRepository {
    var settings: AppSettings
    private(set) var updateCount = 0

    init(_ settings: AppSettings = AppSettings()) {
        self.settings = settings
    }

    func update(_ change: (inout AppSettings) -> Void) {
        change(&settings)
        updateCount += 1
    }
}

/// Задачи и категории в памяти. Логику повторов и напоминаний не воспроизводит:
/// для неё есть тесты `SwiftDataRepository`, а ViewModel проверяют, что и с чем вызвано.
@MainActor
final class FakeTaskRepository: TaskRepository, TaskListRepository {
    private(set) var tasks: [TaskItem] = []
    private(set) var lists: [TaskList] = []

    // Журнал вызовов.
    private(set) var savedDrafts: [(draft: TaskDraft, task: TaskItem?)] = []
    private(set) var completions: [(id: UUID, isCompleted: Bool)] = []
    private(set) var deletedIDs: [UUID] = []
    private(set) var duplicatedIDs: [UUID] = []
    private(set) var restoredIDs: [UUID] = []
    private(set) var scheduled: [(id: UUID, start: Date)] = []
    private(set) var durations: [(id: UUID, minutes: Int)] = []
    private(set) var dayChanges: [(id: UUID, start: Date, end: Date)] = []
    private(set) var movedToTodayIDs: [UUID] = []
    private(set) var rescheduleCalls: [Bool] = []
    private(set) var savedListDrafts: [(draft: TaskListDraft, list: TaskList?)] = []
    private(set) var deletedListIDs: [UUID] = []

    /// Что вернёт `setCompleted` (например, следующее вхождение повторяющейся задачи).
    var nextOccurrence: TaskItem?

    init(tasks: [TaskItem] = [], lists: [TaskList] = []) {
        self.tasks = tasks
        self.lists = lists
    }

    func insert(_ tasks: [TaskItem]) {
        self.tasks += tasks
    }

    @discardableResult
    func save(_ draft: TaskDraft, to task: TaskItem?) -> TaskItem {
        savedDrafts.append((draft, task))
        let item = task ?? TaskItem(title: draft.title, sortOrder: (tasks.map(\.sortOrder).max() ?? 0) + 1)
        item.title = draft.title
        item.notes = draft.notes
        item.dueDate = draft.dueDate
        item.hasTime = draft.hasTime
        item.durationMinutes = draft.durationMinutes
        item.endDay = draft.endDay
        item.priority = draft.priority
        item.reminder = draft.reminder
        item.repeatRule = draft.repeatRule
        item.list = draft.list
        item.isCompleted = draft.isCompleted
        if task == nil { tasks.append(item) }
        return item
    }

    @discardableResult
    func setCompleted(_ task: TaskItem, _ isCompleted: Bool) -> TaskItem? {
        completions.append((task.id, isCompleted))
        task.isCompleted = isCompleted
        if let nextOccurrence, isCompleted {
            tasks.append(nextOccurrence)
            return nextOccurrence
        }
        return nil
    }

    func delete(_ task: TaskItem) {
        deletedIDs.append(task.id)
        tasks.removeAll { $0.id == task.id }
    }

    @discardableResult
    func duplicate(_ task: TaskItem) -> TaskItem {
        duplicatedIDs.append(task.id)
        let copy = TaskItem(title: task.title, dueDate: task.dueDate, hasTime: task.hasTime)
        tasks.append(copy)
        return copy
    }

    func restore(_ snapshot: TaskSnapshot) {
        restoredIDs.append(snapshot.id)
    }

    func schedule(_ task: TaskItem, at start: Date) {
        scheduled.append((task.id, start))
        task.dueDate = start
        task.hasTime = true
    }

    func setDuration(_ task: TaskItem, minutes: Int) {
        durations.append((task.id, minutes))
        task.durationMinutes = minutes
    }

    func setDays(_ task: TaskItem, start: Date, end: Date) {
        dayChanges.append((task.id, start, end))
    }

    func moveToToday(_ task: TaskItem) {
        movedToTodayIDs.append(task.id)
    }

    func rescheduleReminders(enabled: Bool) {
        rescheduleCalls.append(enabled)
    }

    func insert(_ lists: [TaskList]) {
        self.lists += lists
    }

    func save(_ draft: TaskListDraft, to list: TaskList?) {
        savedListDrafts.append((draft, list))
        if let list {
            list.name = draft.name
            list.colorHex = draft.colorHex
            list.symbolName = draft.symbolName
        } else {
            lists.append(TaskList(name: draft.name, colorHex: draft.colorHex, symbolName: draft.symbolName))
        }
    }

    func delete(_ list: TaskList) {
        deletedListIDs.append(list.id)
        lists.removeAll { $0.id == list.id }
    }
}

/// Привычки в памяти с журналом вызовов.
@MainActor
final class FakeHabitRepository: HabitRepository {
    private(set) var habits: [Habit] = []

    private(set) var savedDrafts: [(draft: HabitDraft, habit: Habit?)] = []
    private(set) var deletedIDs: [UUID] = []
    private(set) var values: [(id: UUID, value: Double, day: Date)] = []
    private(set) var skips: [(id: UUID, isSkipped: Bool, day: Date)] = []
    private(set) var rescheduleCalls: [Bool] = []

    let calendar: Calendar

    init(habits: [Habit] = [], calendar: Calendar = TestCalendar.moscow) {
        self.habits = habits
        self.calendar = calendar
    }

    func insert(_ habits: [Habit]) {
        self.habits += habits
    }

    @discardableResult
    func save(_ draft: HabitDraft, to habit: Habit?) -> Habit {
        savedDrafts.append((draft, habit))
        let item = habit ?? Habit(
            name: draft.name, symbolName: draft.symbolName, colorHex: draft.colorHex,
            kind: draft.kind, target: draft.target, unit: draft.unit, step: draft.step,
            frequency: draft.frequency
        )
        item.name = draft.name
        item.weekdays = draft.weekdays
        item.timesPerWeek = draft.timesPerWeek
        item.reminderEnabled = draft.reminderEnabled
        item.reminderMinute = draft.reminderMinute
        if habit == nil { habits.append(item) }
        return item
    }

    func delete(_ habit: Habit) {
        deletedIDs.append(habit.id)
        habits.removeAll { $0.id == habit.id }
    }

    func setValue(_ value: Double, for habit: Habit, on day: Date) {
        values.append((habit.id, value, day))
        log(for: habit, on: day).value = value
    }

    func setSkipped(_ isSkipped: Bool, for habit: Habit, on day: Date) {
        skips.append((habit.id, isSkipped, day))
        log(for: habit, on: day).isSkipped = isSkipped
    }

    func rescheduleReminders(enabled: Bool) {
        rescheduleCalls.append(enabled)
    }

    private func log(for habit: Habit, on day: Date) -> HabitLog {
        if let log = habit.log(on: day, calendar: calendar) { return log }
        let log = HabitLog(day: calendar.startOfDay(for: day))
        habit.logs.append(log)
        return log
    }
}
