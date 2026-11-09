import Foundation
import Testing
@testable import TickFlow

@MainActor
struct TaskItemTests {
    let fixture: ModelFixture
    let calendar = TestCalendar.moscow
    let now = date("2026-11-08 09:00")

    init() throws {
        fixture = try ModelFixture()
    }

    // MARK: - occurs(on:)

    @Test func taskWithoutDateNeverOccurs() {
        let task = fixture.task()
        #expect(!task.occurs(on: now, calendar: calendar))
        #expect(task.lastDay(calendar: calendar) == nil)
        #expect(!task.isMultiDay(calendar: calendar))
    }

    @Test func singleDayTaskOccursOnlyOnItsDay() {
        let task = fixture.task(due: "2026-11-08 15:00")
        #expect(task.occurs(on: date("2026-11-08 00:00"), calendar: calendar))
        #expect(task.occurs(on: date("2026-11-08 23:59"), calendar: calendar))
        #expect(!task.occurs(on: date("2026-11-07 23:59"), calendar: calendar))
        #expect(!task.occurs(on: date("2026-11-09"), calendar: calendar))
    }

    @Test func multiDayTaskOccursOnEveryDayOfRange() {
        let task = fixture.task(due: "2026-11-08", endDay: "2026-11-10")
        #expect(task.isMultiDay(calendar: calendar))
        #expect(task.lastDay(calendar: calendar) == date("2026-11-10"))
        #expect(!task.occurs(on: date("2026-11-07"), calendar: calendar))
        #expect(task.occurs(on: date("2026-11-08 12:00"), calendar: calendar))
        #expect(task.occurs(on: date("2026-11-09"), calendar: calendar))
        #expect(task.occurs(on: date("2026-11-10 23:00"), calendar: calendar))
        #expect(!task.occurs(on: date("2026-11-11"), calendar: calendar))
    }

    @Test func endDayOnSameDayIsNotMultiDay() {
        let task = fixture.task(due: "2026-11-08 10:00", endDay: "2026-11-08")
        #expect(!task.isMultiDay(calendar: calendar))
    }

    // MARK: - endDate

    @Test func endDateAddsDurationForTimedTask() {
        #expect(fixture.task(due: "2026-11-08 09:00", minutes: 90).endDate == date("2026-11-08 10:30"))
        #expect(fixture.task(due: "2026-11-08 23:30", minutes: 60).endDate == date("2026-11-09 00:30"))
    }

    @Test func taskWithoutTimeHasNoEndDate() {
        #expect(fixture.task(due: "2026-11-08").endDate == nil)
        #expect(fixture.task().endDate == nil)
    }

    // MARK: - isOverdue

    @Test func overdueOnlyAfterLastDayPassed() {
        #expect(!fixture.task(due: "2026-11-08 07:00").isOverdue(now: now, calendar: calendar))
        #expect(!fixture.task(due: "2026-11-08").isOverdue(now: now, calendar: calendar))
        #expect(fixture.task(due: "2026-11-07 23:00").isOverdue(now: now, calendar: calendar))
        #expect(!fixture.task(due: "2026-11-09").isOverdue(now: now, calendar: calendar))
    }

    @Test func completedOrUndatedTaskIsNeverOverdue() {
        #expect(!fixture.task(due: "2026-11-01", completed: true).isOverdue(now: now, calendar: calendar))
        #expect(!fixture.task().isOverdue(now: now, calendar: calendar))
    }

    @Test func multiDayTaskIsOverdueOnlyAfterItsLastDay() {
        let task = fixture.task(due: "2026-11-05", endDay: "2026-11-08")
        #expect(!task.isOverdue(now: now, calendar: calendar))
        #expect(task.isOverdue(now: date("2026-11-09 00:01"), calendar: calendar))
    }

    // MARK: - reminderDate

    @Test(arguments: [
        (ReminderOption.atTime, "2026-11-08 12:00"),
        (.tenMinutesBefore, "2026-11-08 11:50"),
        (.hourBefore, "2026-11-08 11:00"),
    ])
    func reminderFiresBeforeStart(option: ReminderOption, expected: String) {
        let task = fixture.task(due: "2026-11-08 12:00", reminder: option)
        #expect(task.reminderDate(now: now) == date(expected))
    }

    @Test func reminderInPastIsDropped() {
        let task = fixture.task(due: "2026-11-08 12:00", reminder: .tenMinutesBefore)
        #expect(task.reminderDate(now: date("2026-11-08 11:50")) == nil)
        #expect(task.reminderDate(now: date("2026-11-08 11:49")) == date("2026-11-08 11:50"))
    }

    @Test func noReminderWithoutTimeOptionOrWhenCompleted() {
        #expect(fixture.task(due: "2026-11-09", reminder: .atTime).reminderDate(now: now) == nil)
        #expect(fixture.task(due: "2026-11-09 12:00", reminder: .none).reminderDate(now: now) == nil)
        #expect(fixture.task(due: "2026-11-09 12:00", reminder: .atTime, completed: true).reminderDate(now: now) == nil)
        #expect(fixture.task(reminder: .atTime).reminderDate(now: now) == nil)
    }

    // MARK: - Изменения

    @Test func setCompletedStoresAndClearsCompletionDate() {
        let task = fixture.task(due: "2026-11-08")
        task.setCompleted(true, at: now)
        #expect(task.isCompleted)
        #expect(task.completedAt == now)

        task.setCompleted(false, at: now)
        #expect(!task.isCompleted)
        #expect(task.completedAt == nil)
    }

    @Test func moveToTodayKeepsTimeAndDropsEndDay() {
        let task = fixture.task(due: "2026-11-03 14:30", endDay: "2026-11-04")
        task.moveToToday(calendar: calendar, now: now)
        #expect(task.dueDate == date("2026-11-08 14:30"))
        #expect(task.endDay == nil)
        #expect(task.hasTime)
    }

    @Test func moveToTodayWithoutTimeUsesStartOfDay() {
        let task = fixture.task(due: "2026-11-03", endDay: "2026-11-05")
        task.moveToToday(calendar: calendar, now: now)
        #expect(task.dueDate == date("2026-11-08"))
        #expect(task.endDay == nil)
        #expect(!task.hasTime)
    }

    @Test func moveToTodayForUndatedTask() {
        let task = fixture.task()
        task.moveToToday(calendar: calendar, now: now)
        #expect(task.dueDate == date("2026-11-08"))
    }

    // MARK: - Подзадачи

    @Test func subtasksAreSortedAndCounted() {
        let task = fixture.task()
        task.subtasks.append(Subtask(title: "Третья", isCompleted: true, sortOrder: 2))
        task.subtasks.append(Subtask(title: "Первая", isCompleted: false, sortOrder: 0))
        task.subtasks.append(Subtask(title: "Вторая", isCompleted: true, sortOrder: 1))

        #expect(task.sortedSubtasks.map(\.title) == ["Первая", "Вторая", "Третья"])
        #expect(task.completedSubtaskCount == 2)
    }

    @Test func rawValuesFallBackToDefaults() {
        let task = fixture.task()
        task.priorityRaw = 99
        task.reminderRaw = 99
        task.repeatRaw = 99
        #expect(task.priority == .none)
        #expect(task.reminder == .none)
        #expect(task.repeatRule == .never)
    }
}
