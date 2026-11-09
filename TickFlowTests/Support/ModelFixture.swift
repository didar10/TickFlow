import Foundation
import SwiftData
@testable import TickFlow

/// Модели в базе в памяти: связи (подзадачи, отметки привычек) работают так же, как в приложении.
@MainActor
final class ModelFixture {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let calendar: Calendar

    init(calendar: Calendar = TestCalendar.moscow) throws {
        container = try makeInMemoryContainer()
        self.calendar = calendar
    }

    @discardableResult
    func task(
        _ title: String = "Задача",
        due: String? = nil,
        hasTime: Bool? = nil,
        minutes: Int = 60,
        endDay: String? = nil,
        priority: Priority = .none,
        reminder: ReminderOption = .none,
        repeatRule: RepeatRule = .never,
        list: TaskList? = nil,
        completed: Bool = false
    ) -> TaskItem {
        let item = TaskItem(
            title: title,
            dueDate: due.map { date($0, calendar: calendar) },
            hasTime: hasTime ?? (due?.contains(":") ?? false),
            durationMinutes: minutes,
            priority: priority,
            list: list
        )
        item.endDay = endDay.map { date($0, calendar: calendar) }
        item.reminder = reminder
        item.repeatRule = repeatRule
        item.isCompleted = completed
        context.insert(item)
        return item
    }

    func addSubtasks(_ items: [(String, Bool)], to task: TaskItem) {
        for (index, item) in items.enumerated() {
            task.subtasks.append(Subtask(title: item.0, isCompleted: item.1, sortOrder: index))
        }
    }

    @discardableResult
    func list(_ name: String, color: String = "#5B5BD6") -> TaskList {
        let list = TaskList(name: name, colorHex: color, symbolName: "folder")
        context.insert(list)
        return list
    }

    @discardableResult
    func habit(
        _ name: String = "Привычка",
        kind: HabitKind = .check,
        target: Double = 1,
        unit: String = "",
        frequency: HabitFrequency = .daily,
        weekdays: [Int] = [1, 2, 3, 4, 5, 6, 7],
        timesPerWeek: Int = 3,
        start: String = "2026-11-01"
    ) -> Habit {
        let habit = Habit(
            name: name, symbolName: "book", colorHex: "#5B5BD6",
            kind: kind, target: target, unit: unit, step: 1,
            frequency: frequency, weekdays: weekdays, timesPerWeek: timesPerWeek,
            startDate: date(start, calendar: calendar)
        )
        context.insert(habit)
        return habit
    }

    /// Отметка за день. По умолчанию — выполнение цели.
    func log(_ habit: Habit, _ day: String, value: Double? = nil, skipped: Bool = false) {
        let log = HabitLog(day: date(day, calendar: calendar), value: value ?? (skipped ? 0 : habit.target), isSkipped: skipped)
        habit.logs.append(log)
    }

    func done(_ habit: Habit, _ days: String...) {
        days.forEach { log(habit, $0) }
    }
}
