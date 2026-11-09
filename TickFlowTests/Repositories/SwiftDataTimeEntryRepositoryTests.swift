import Foundation
import SwiftData
import Testing
@testable import TickFlow

@MainActor
struct SwiftDataTimeEntryRepositoryTests {
    let container: ModelContainer
    let clock = FixedClock("2026-11-08 09:00")
    let tasks: SwiftDataRepository
    let repository: SwiftDataTimeEntryRepository

    init() throws {
        container = try makeInMemoryContainer()
        tasks = SwiftDataRepository(
            context: container.mainContext,
            clock: clock,
            calendar: TestCalendar.moscow,
            reminders: FakeReminderScheduler()
        )
        repository = SwiftDataTimeEntryRepository(context: container.mainContext)
    }

    private func taskDraft(_ title: String = "Отчёт", list: TaskList? = nil) -> TaskDraft {
        TaskDraft(
            title: title, notes: "", dueDate: date("2026-11-08 11:30"), hasTime: true,
            durationMinutes: 90, endDay: nil, priority: .none, reminder: .none,
            repeatRule: .never, list: list, subtasks: []
        )
    }

    private func entryDraft(
        _ start: String, _ end: String, task: TaskItem? = nil,
        kind: TimeEntryKind = .focus, status: TimeEntryStatus = .completed
    ) -> TimeEntryDraft {
        TimeEntryDraft(task: task, start: date(start), end: date(end), kind: kind, status: status)
    }

    // MARK: - Записи

    @Test func addKeepsEntriesSortedByStart() throws {
        let task = tasks.save(taskDraft(), to: nil)
        repository.add(entryDraft("2026-11-08 10:00", "2026-11-08 10:25", task: task))
        repository.add(entryDraft("2026-11-08 08:05", "2026-11-08 08:30"))

        #expect(repository.entries.map(\.start) == [date("2026-11-08 08:05"), date("2026-11-08 10:00")])
        #expect(task.timeEntries.count == 1)
        #expect(task.trackedMinutes == 25)
    }

    @Test func invalidEntryIsNotSaved() throws {
        #expect(repository.add(entryDraft("2026-11-08 10:00", "2026-11-08 10:00")) == nil)
        #expect(repository.add(entryDraft("2026-11-08 10:00", "2026-11-08 09:00")) == nil)
        #expect(repository.entries.isEmpty)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<TimeEntry>()) == 0)
    }

    @Test func updateChangesTaskTimeAndStatusButNotKind() throws {
        let first = tasks.save(taskDraft("A"), to: nil)
        let second = tasks.save(taskDraft("B"), to: nil)
        let entry = try #require(repository.add(entryDraft("2026-11-08 10:00", "2026-11-08 10:25", task: first, kind: .timer)))

        repository.update(entry, with: entryDraft("2026-11-08 10:05", "2026-11-08 10:45", task: second,
                                                  kind: .manual, status: .interrupted))

        #expect(entry.task?.id == second.id)
        #expect(entry.durationMinutes == 40)
        #expect(entry.status == .interrupted)
        #expect(entry.kind == .timer)
        #expect(first.timeEntries.isEmpty)
    }

    @Test func invalidUpdateIsIgnored() throws {
        let entry = try #require(repository.add(entryDraft("2026-11-08 10:00", "2026-11-08 10:25")))
        repository.update(entry, with: entryDraft("2026-11-08 11:00", "2026-11-08 10:00"))
        #expect(entry.start == date("2026-11-08 10:00"))
        #expect(entry.end == date("2026-11-08 10:25"))
    }

    @Test func deleteRemovesEntryOnly() throws {
        let task = tasks.save(taskDraft(), to: nil)
        let entry = try #require(repository.add(entryDraft("2026-11-08 10:00", "2026-11-08 10:25", task: task)))
        repository.delete(entry)

        #expect(repository.entries.isEmpty)
        #expect(tasks.tasks.count == 1)
        #expect(task.timeEntries.isEmpty)
    }

    @Test func entriesForTaskAndDay() throws {
        let task = tasks.save(taskDraft(), to: nil)
        repository.add(entryDraft("2026-11-07 18:00", "2026-11-07 18:25", task: task))
        repository.add(entryDraft("2026-11-08 10:00", "2026-11-08 10:25", task: task))
        repository.add(entryDraft("2026-11-08 12:00", "2026-11-08 12:25"))

        #expect(repository.entries(for: task).map(\.start) == [date("2026-11-08 10:00"), date("2026-11-07 18:00")])
        #expect(repository.entries(on: date("2026-11-08"), calendar: TestCalendar.moscow).count == 2)
    }

    // MARK: - Связь с задачей

    @Test func deletingTaskKeepsHistoryWithoutLink() throws {
        let task = tasks.save(taskDraft(), to: nil)
        let entry = try #require(repository.add(entryDraft("2026-11-08 10:00", "2026-11-08 10:25", task: task)))

        tasks.delete(task)
        repository.reload()

        #expect(repository.entries.count == 1)
        #expect(entry.task == nil)
    }

    @Test func restoringDeletedTaskRelinksEntries() throws {
        let task = tasks.save(taskDraft(), to: nil)
        repository.add(entryDraft("2026-11-08 10:00", "2026-11-08 10:25", task: task))
        repository.add(entryDraft("2026-11-08 11:00", "2026-11-08 11:15", task: task, kind: .manual))
        let snapshot = TaskSnapshot(task)
        #expect(snapshot.timeEntryIDs.count == 2)

        tasks.delete(task)
        tasks.restore(snapshot)

        let restored = try #require(tasks.tasks.first)
        #expect(restored.id == snapshot.id)
        #expect(restored.trackedMinutes == 40)
        #expect(repository.entries.allSatisfy { $0.task?.id == snapshot.id })
    }

    @Test func deletingCategoryKeepsEntries() throws {
        tasks.save(TaskListDraft(name: "Работа", colorHex: "#111111", symbolName: "a"), to: nil)
        let list = try #require(tasks.lists.first)
        let task = tasks.save(taskDraft(list: list), to: nil)
        repository.add(entryDraft("2026-11-08 10:00", "2026-11-08 10:25", task: task))

        tasks.delete(list)
        repository.reload()

        #expect(tasks.tasks.isEmpty)
        #expect(repository.entries.count == 1)
        #expect(repository.entries[0].task == nil)
    }

    // MARK: - Поля задачи и категории

    @Test func trackingAndEstimateArePersistedAndCarriedOver() throws {
        var draft = taskDraft()
        draft.trackingOverride = true
        draft.estimateMinutes = 150
        draft.repeatRule = .daily
        let task = tasks.save(draft, to: nil)
        #expect(task.trackingOverride == true)
        #expect(task.estimateMinutes == 150)

        let copy = tasks.duplicate(task)
        #expect(copy.trackingOverride == true)
        #expect(copy.estimateMinutes == 150)

        let next = try #require(tasks.setCompleted(task, true))
        #expect(next.trackingOverride == true)
        #expect(next.estimateMinutes == 150)
    }

    @Test func setTrackingAndEstimate() {
        let task = tasks.save(taskDraft(), to: nil)
        tasks.setTracking(task, false)
        #expect(task.trackingOverride == false)
        tasks.setTracking(task, nil)
        #expect(task.trackingOverride == nil)

        tasks.setEstimate(task, minutes: -15)
        #expect(task.estimateMinutes == 0)
        tasks.setEstimate(task, minutes: 45)
        #expect(task.effectiveEstimate == 45)
        tasks.setEstimate(task, minutes: nil)
        #expect(task.effectiveEstimate == 90)
        #expect(task.updatedAt == clock.now)
    }

    @Test func categoryTrackingDefaultIsSaved() throws {
        tasks.save(TaskListDraft(name: "Учёба", colorHex: "#111111", symbolName: "a", tracksTimeByDefault: true), to: nil)
        let list = try #require(tasks.lists.first)
        #expect(list.tracksTimeByDefault)

        tasks.save(TaskListDraft(name: "Учёба", colorHex: "#111111", symbolName: "a", tracksTimeByDefault: false), to: list)
        #expect(!list.tracksTimeByDefault)
    }
}
