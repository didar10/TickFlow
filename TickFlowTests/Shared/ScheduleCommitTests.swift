import Foundation
import Testing
@testable import TickFlow

@MainActor
struct ScheduleCommitTests {
    let fixture: ModelFixture
    let calendar = TestCalendar.moscow

    init() throws {
        fixture = try ModelFixture()
    }

    // MARK: - gapNote

    private func note(for task: TaskItem, in tasks: [TaskItem]) -> String {
        ScheduleCommit.gapNote(
            start: task.dueDate!, end: task.endDate!, excluding: task.id, in: tasks, calendar: calendar
        )
    }

    @Test func backToBackWithNextTask() {
        let task = fixture.task("Обед", due: "2026-11-08 12:00")
        let next = fixture.task("Созвон", due: "2026-11-08 13:00")
        #expect(note(for: task, in: [task, next]) == " · Встык с «Созвон»")
    }

    @Test func backToBackWithPreviousTask() {
        let previous = fixture.task("Почта", due: "2026-11-08 11:00")
        let task = fixture.task("Обед", due: "2026-11-08 12:00")
        #expect(note(for: task, in: [previous, task]) == " · Встык с «Почта»")
    }

    @Test func shortBreakUnderTenMinutes() {
        let task = fixture.task(due: "2026-11-08 12:00")
        #expect(note(for: task, in: [task, fixture.task(due: "2026-11-08 13:05")]) == " · Перерыв всего 5 мин")
        #expect(note(for: task, in: [task, fixture.task(due: "2026-11-08 10:51")]) == " · Перерыв всего 9 мин")
    }

    @Test func noNoteForLongBreakOrOverlap() {
        let task = fixture.task(due: "2026-11-08 12:00")
        #expect(note(for: task, in: [task, fixture.task(due: "2026-11-08 13:10")]).isEmpty)
        #expect(note(for: task, in: [task, fixture.task(due: "2026-11-08 12:30")]).isEmpty)
        #expect(note(for: task, in: [task]).isEmpty)
    }

    @Test func ignoresCompletedUntimedMultiDayAndOtherDays() {
        let task = fixture.task(due: "2026-11-08 12:00")
        let others = [
            fixture.task(due: "2026-11-08 13:00", completed: true),
            fixture.task(due: "2026-11-08"),
            fixture.task(due: "2026-11-08 13:00", endDay: "2026-11-09"),
            fixture.task(due: "2026-11-09 13:00"),
        ]
        #expect(note(for: task, in: [task] + others).isEmpty)
    }

    @Test func recurringMessage() {
        #expect(
            ScheduleCommit.recurringMessage(title: "Пробежка", rule: .weekly)
                == "«Пробежка» повторяется (каждую неделю). К чему применить изменение?"
        )
    }

    // MARK: - commit

    private func draft(from task: TaskItem, due: String) -> TaskDraft {
        var draft = TaskSnapshot(task).draft
        draft.dueDate = date(due)
        return draft
    }

    @Test func thisOccurrenceSplitsSeries() {
        let repository = FakeTaskRepository()
        let task = fixture.task("Пробежка", due: "2026-11-08 07:00", repeatRule: .daily)
        repository.insert([task])

        _ = ScheduleCommit.commit(draft(from: task, due: "2026-11-08 08:00"), to: task, scope: .thisOccurrence, repository: repository)

        #expect(repository.savedDrafts.count == 2)
        let series = repository.savedDrafts[0]
        #expect(series.task == nil)
        #expect(series.draft.repeatRule == .daily)
        // Серия продолжается по старому расписанию со следующего дня.
        #expect(series.draft.dueDate == RepeatRule.daily.nextDate(after: date("2026-11-08 07:00")))

        let edited = repository.savedDrafts[1]
        #expect(edited.task === task)
        #expect(edited.draft.repeatRule == .never)
        #expect(edited.draft.dueDate == date("2026-11-08 08:00"))
    }

    @Test func thisAndFollowingChangesWholeSeries() {
        let repository = FakeTaskRepository()
        let task = fixture.task(due: "2026-11-08 07:00", repeatRule: .daily)

        _ = ScheduleCommit.commit(draft(from: task, due: "2026-11-08 08:00"), to: task, scope: .thisAndFollowing, repository: repository)

        #expect(repository.savedDrafts.count == 1)
        #expect(repository.savedDrafts[0].draft.repeatRule == .daily)
    }

    @Test func nonRecurringTaskSavesOnce() {
        let repository = FakeTaskRepository()
        let task = fixture.task(due: "2026-11-08 07:00")
        _ = ScheduleCommit.commit(draft(from: task, due: "2026-11-09 07:00"), to: task, scope: nil, repository: repository)
        #expect(repository.savedDrafts.count == 1)
    }

    @Test func undoRemovesContinuationAndRestoresTask() {
        let repository = FakeTaskRepository()
        let task = fixture.task(due: "2026-11-08 07:00", repeatRule: .weekly)
        repository.insert([task])

        let undo = ScheduleCommit.commit(draft(from: task, due: "2026-11-08 09:00"), to: task, scope: .thisOccurrence, repository: repository)
        let continuation = repository.tasks.first { $0.id != task.id }
        #expect(continuation != nil)

        undo()
        #expect(repository.deletedIDs == [continuation?.id].compactMap { $0 })
        #expect(repository.restoredIDs == [task.id])
    }

    @Test func undoWithoutSplitOnlyRestores() {
        let repository = FakeTaskRepository()
        let task = fixture.task(due: "2026-11-08 07:00")
        let undo = ScheduleCommit.commit(draft(from: task, due: "2026-11-09 07:00"), to: task, scope: nil, repository: repository)
        undo()
        #expect(repository.deletedIDs.isEmpty)
        #expect(repository.restoredIDs == [task.id])
    }
}
