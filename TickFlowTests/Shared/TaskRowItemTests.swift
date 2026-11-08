import Foundation
import Testing
@testable import TickFlow

@MainActor
struct TaskRowItemTests {
    let fixture: ModelFixture
    let format = DisplayFormatter(
        settings: AppSettings(),
        base: TestCalendar.moscow,
        clock: FixedClock("2026-11-08 09:00"),
        locale: Locale(identifier: "ru_RU")
    )

    init() throws {
        fixture = try ModelFixture()
    }

    private func row(_ task: TaskItem, all: [TaskItem]? = nil, meta: String? = nil) -> TaskRowItem {
        TaskRowItem(task: task, format: format, allTasks: all ?? [task], meta: meta)
    }

    @Test func plainTask() {
        let task = fixture.task("Купить хлеб")
        let row = row(task)
        #expect(row.id == task.id)
        #expect(row.title == "Купить хлеб")
        #expect(row.priorityMarks == "")
        #expect(row.meta == "Без даты")
        #expect(row.categoryName == "Без категории")
        #expect(row.categoryColorHex == AppColors.fallbackList)
        #expect(row.subtaskProgress == nil)
        #expect(!row.hasReminder)
        #expect(!row.isRepeating)
        #expect(!row.hasConflict)
        #expect(!row.isOverdue)
        #expect(!row.isCompleted)
        #expect(!row.isUrgent)
    }

    @Test func categoryAndMeta() {
        let list = fixture.list("Работа", color: "#FF0000")
        let row = row(fixture.task(due: "2026-11-08 10:00", list: list))
        #expect(row.categoryName == "Работа")
        #expect(row.categoryColorHex == "#FF0000")
        #expect(row.meta == "Сегодня, 10:00")
    }

    @Test func explicitMetaOverridesDueLabel() {
        #expect(row(fixture.task(due: "2026-11-08"), meta: "Своя подпись").meta == "Своя подпись")
    }

    @Test func subtaskProgress() {
        let task = fixture.task()
        fixture.addSubtasks([("A", true), ("B", true), ("C", false)], to: task)
        #expect(row(task).subtaskProgress == "2/3")
    }

    @Test func reminderFlagNeedsDate() {
        #expect(row(fixture.task(due: "2026-11-09 10:00", reminder: .atTime)).hasReminder)
        #expect(!row(fixture.task(reminder: .atTime)).hasReminder)
        #expect(!row(fixture.task(due: "2026-11-09 10:00", reminder: .none)).hasReminder)
    }

    @Test func repeatFlag() {
        #expect(row(fixture.task(due: "2026-11-09", repeatRule: .weekdays)).isRepeating)
    }

    @Test func conflictFlag() {
        let a = fixture.task(due: "2026-11-08 10:00")
        let b = fixture.task(due: "2026-11-08 10:30")
        #expect(row(a, all: [a, b]).hasConflict)
        #expect(!row(a, all: [a]).hasConflict)
    }

    @Test func overdueUsesFormatterClock() {
        #expect(row(fixture.task(due: "2026-11-07")).isOverdue)
        #expect(!row(fixture.task(due: "2026-11-08")).isOverdue)
    }

    @Test(arguments: [(Priority.none, "", false), (.low, "!", false), (.medium, "!!", false), (.high, "!!!", true)])
    func priority(priority: Priority, marks: String, urgent: Bool) {
        let row = row(fixture.task(priority: priority))
        #expect(row.priorityMarks == marks)
        #expect(row.isUrgent == urgent)
    }

    @Test func completedTask() {
        let row = row(fixture.task(due: "2026-11-01", completed: true))
        #expect(row.isCompleted)
        #expect(!row.isOverdue)
    }
}
