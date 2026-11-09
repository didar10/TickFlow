import Foundation
import SwiftData
import Testing
@testable import TickFlow

/// Дымовые тесты примера данных. `SeedService` берёт `Calendar.current` и `.now`,
/// поэтому проверяем только структуру, а не конкретные даты.
@MainActor
struct SeedServiceTests {
    let container: ModelContainer
    let repository: SwiftDataRepository
    let habitRepository: SwiftDataHabitRepository

    init() throws {
        container = try makeInMemoryContainer()
        repository = SwiftDataRepository(context: container.mainContext, reminders: FakeReminderScheduler())
        habitRepository = SwiftDataHabitRepository(context: container.mainContext, reminders: FakeReminderScheduler())
    }

    private func seedIfNeeded() {
        SeedService.seedIfNeeded(tasks: repository, lists: repository, habits: habitRepository)
    }

    private func seedSample() {
        SeedService.seedSample(tasks: repository, lists: repository, habits: habitRepository)
    }

    @Test func seedsEmptyDatabase() {
        seedIfNeeded()

        #expect(repository.lists.map(\.name) == [
            L10n.Sample.work, L10n.Sample.personal, L10n.Sample.health, L10n.Sample.errands, L10n.Sample.learning,
        ])
        #expect(repository.tasks.count > 26) // 26 задач макета + история за прошлые недели
        #expect(habitRepository.habits.count == 5)
        #expect(habitRepository.habits.allSatisfy { !$0.logs.isEmpty })
    }

    @Test func seededDataIsConsistent() {
        seedIfNeeded()
        let tasks = repository.tasks

        #expect(tasks.allSatisfy { $0.list != nil })
        #expect(Set(tasks.map(\.sortOrder)).count == tasks.count)
        #expect(tasks.contains { $0.dueDate == nil })
        #expect(tasks.contains { $0.isCompleted })
        #expect(tasks.contains { $0.repeatRule != .never })
        #expect(tasks.contains { !$0.subtasks.isEmpty })

        let multiDay = tasks.filter { $0.endDay != nil }
        #expect(!multiDay.isEmpty)
        for task in multiDay {
            #expect(task.dueDate.flatMap { due in task.endDay.map { $0 > due } } == true)
        }
        for task in tasks where task.isCompleted {
            #expect(task.completedAt != nil)
        }
        for task in tasks where task.hasTime {
            #expect(task.durationMinutes > 0)
        }
    }

    @Test func skipsWhenDatabaseHasData() {
        repository.insert([TaskList(name: "Своя", colorHex: "#000000", symbolName: "folder")])

        seedIfNeeded()

        #expect(repository.lists.map(\.name) == ["Своя"])
        #expect(repository.tasks.isEmpty)
        #expect(habitRepository.habits.isEmpty)
    }

    @Test func runsTwiceOnlyOnce() {
        seedIfNeeded()
        let counts = (repository.lists.count, repository.tasks.count, habitRepository.habits.count)

        seedIfNeeded()

        #expect(repository.lists.count == counts.0)
        #expect(repository.tasks.count == counts.1)
        #expect(habitRepository.habits.count == counts.2)
    }

    /// «Загрузить пример» поверх своих данных: категории и привычки не дублируются,
    /// задачи добавляются в существующие категории и встают после своих.
    @Test func sampleOverExistingData() {
        let own = TaskList(name: "Своя", colorHex: "#000000", symbolName: "folder")
        repository.insert([own])
        let mine = TaskItem(title: "Моя задача", list: own, sortOrder: 40)
        repository.insert([mine])
        habitRepository.insert([Habit(name: "Своя привычка", symbolName: "book", colorHex: "#000000", kind: .check,
                                      target: 1, unit: "", step: 1, frequency: .daily)])

        seedSample()

        #expect(repository.lists.map(\.name) == ["Своя"])
        #expect(habitRepository.habits.map(\.name) == ["Своя привычка"])
        let added = repository.tasks.filter { $0.id != mine.id }
        #expect(!added.isEmpty)
        #expect(added.allSatisfy { $0.list?.id == own.id })
        #expect(added.allSatisfy { $0.sortOrder > 40 })
    }
}
