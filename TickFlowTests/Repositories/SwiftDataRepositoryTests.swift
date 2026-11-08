import Foundation
import SwiftData
import Testing
@testable import TickFlow

/// Сегодня — воскресенье 08.11.2026, 09:00 (Москва).
@MainActor
struct SwiftDataRepositoryTests {
    let container: ModelContainer
    let clock = FixedClock("2026-11-08 09:00")
    let reminders = FakeReminderScheduler()
    let repository: SwiftDataRepository

    init() throws {
        container = try makeInMemoryContainer()
        repository = SwiftDataRepository(
            context: container.mainContext,
            clock: clock,
            calendar: TestCalendar.moscow,
            reminders: reminders
        )
    }

    private func draft(
        _ title: String = "Задача",
        due: String? = "2026-11-08 12:00",
        minutes: Int = 60,
        endDay: String? = nil,
        reminder: ReminderOption = .none,
        repeatRule: RepeatRule = .never,
        list: TaskList? = nil,
        subtasks: [SubtaskDraft] = [],
        completed: Bool = false
    ) -> TaskDraft {
        TaskDraft(
            title: title, notes: "", dueDate: due.map { date($0) }, hasTime: due?.contains(":") ?? false,
            durationMinutes: minutes, endDay: endDay.map { date($0) }, priority: .none,
            reminder: reminder, repeatRule: repeatRule, list: list, subtasks: subtasks, isCompleted: completed
        )
    }

    private func subtask(_ title: String, done: Bool = false) -> SubtaskDraft {
        SubtaskDraft(id: UUID(), title: title, isCompleted: done)
    }

    private func count<T: PersistentModel>(_ type: T.Type) throws -> Int {
        try container.mainContext.fetchCount(FetchDescriptor<T>())
    }

    // MARK: - save

    @Test func savesNewTasksWithGrowingSortOrder() {
        let first = repository.save(draft("Первая"), to: nil)
        let second = repository.save(draft("Вторая"), to: nil)

        #expect(repository.tasks.map(\.title) == ["Первая", "Вторая"])
        #expect(second.sortOrder == first.sortOrder + 1)
        #expect(first.updatedAt == clock.now)
        #expect(first.dueDate == date("2026-11-08 12:00"))
        #expect(first.hasTime)
    }

    @Test func editingKeepsIdentityAndSortOrder() {
        let task = repository.save(draft("Старое"), to: nil)
        let id = task.id, order = task.sortOrder
        clock.advance(minutes: 5)

        repository.save(draft("Новое", due: "2026-11-09"), to: task)

        #expect(repository.tasks.count == 1)
        #expect(task.id == id)
        #expect(task.sortOrder == order)
        #expect(task.title == "Новое")
        #expect(!task.hasTime)
        #expect(task.updatedAt == clock.now)
    }

    @Test func endDayIsStoredOnlyForRealMultiDayRange() {
        let multi = repository.save(draft(due: "2026-11-08", endDay: "2026-11-10 15:00"), to: nil)
        #expect(multi.endDay == date("2026-11-10"))

        let sameDay = repository.save(draft(due: "2026-11-08 10:00", endDay: "2026-11-08 18:00"), to: nil)
        #expect(sameDay.endDay == nil)

        let reversed = repository.save(draft(due: "2026-11-08", endDay: "2026-11-05"), to: nil)
        #expect(reversed.endDay == nil)
    }

    @Test func savesSubtasksInOrder() throws {
        let task = repository.save(draft(subtasks: [subtask("A"), subtask("B", done: true), subtask("C")]), to: nil)
        #expect(task.sortedSubtasks.map(\.title) == ["A", "B", "C"])
        #expect(task.sortedSubtasks.map(\.isCompleted) == [false, true, false])
        #expect(try count(Subtask.self) == 3)
    }

    @Test func editingSubtasksAddsRemovesAndReorders() throws {
        let a = subtask("A"), b = subtask("B"), c = subtask("C")
        let task = repository.save(draft(subtasks: [a, b, c]), to: nil)
        let originalB = task.subtasks.first { $0.id == b.id }

        var renamedB = b
        renamedB.title = "B2"
        renamedB.isCompleted = true
        let d = subtask("D")
        repository.save(draft(subtasks: [c, renamedB, d]), to: task)

        #expect(task.sortedSubtasks.map(\.title) == ["C", "B2", "D"])
        #expect(task.sortedSubtasks.map(\.id) == [c.id, b.id, d.id])
        #expect(task.subtasks.first { $0.id == b.id } === originalB)
        #expect(try count(Subtask.self) == 3)
    }

    @Test func savesCategory() {
        repository.save(TaskListDraft(name: "Работа", colorHex: "#FF0000", symbolName: "briefcase"), to: nil)
        let list = repository.lists[0]
        let task = repository.save(draft(list: list), to: nil)
        #expect(task.list === list)
        #expect(list.tasks.map(\.id) == [task.id])
    }

    @Test func completingThroughDraftSetsCompletionDate() {
        let task = repository.save(draft(completed: true), to: nil)
        #expect(task.isCompleted)
        #expect(task.completedAt == clock.now)
    }

    // MARK: - setCompleted

    @Test func completesPlainTask() {
        let task = repository.save(draft(), to: nil)
        let next = repository.setCompleted(task, true)

        #expect(next == nil)
        #expect(task.isCompleted)
        #expect(task.completedAt == clock.now)
        #expect(repository.tasks.count == 1)

        repository.setCompleted(task, false)
        #expect(!task.isCompleted)
        #expect(task.completedAt == nil)
    }

    @Test func completingRecurringTaskCreatesNextOccurrence() throws {
        repository.save(TaskListDraft(name: "Спорт", colorHex: "#00FF00", symbolName: "figure.run"), to: nil)
        let list = repository.lists[0]
        let task = repository.save(
            draft("Пробежка", due: "2026-11-08 07:00", minutes: 45, reminder: .tenMinutesBefore,
                  repeatRule: .daily, list: list, subtasks: [subtask("Разминка", done: true), subtask("5 км")]),
            to: nil
        )

        let next = try #require(repository.setCompleted(task, true))

        // Выполненное вхождение остаётся в истории без правила.
        #expect(task.isCompleted)
        #expect(task.repeatRule == .never)
        // Следующее — то же время, длительность, категория, правило; подзадачи сброшены.
        #expect(next.id != task.id)
        #expect(next.title == "Пробежка")
        #expect(next.dueDate == date("2026-11-09 07:00"))
        #expect(next.hasTime)
        #expect(next.durationMinutes == 45)
        #expect(next.list === list)
        #expect(next.repeatRule == .daily)
        #expect(next.reminder == .tenMinutesBefore)
        #expect(!next.isCompleted)
        #expect(next.sortedSubtasks.map(\.title) == ["Разминка", "5 км"])
        #expect(next.sortedSubtasks.allSatisfy { !$0.isCompleted })
        #expect(Set(next.subtasks.map(\.id)).isDisjoint(with: task.subtasks.map(\.id)))
        #expect(next.sortOrder > task.sortOrder)
        #expect(repository.tasks.count == 2)

        #expect(reminders.lastFireDate(for: task.id) == nil)
        #expect(reminders.lastFireDate(for: next.id) == date("2026-11-09 06:50"))
    }

    @Test func recurringMultiDayTaskKeepsSpan() throws {
        let task = repository.save(draft(due: "2026-11-08", endDay: "2026-11-10", repeatRule: .weekly), to: nil)
        let next = try #require(repository.setCompleted(task, true))
        #expect(next.dueDate == date("2026-11-15"))
        #expect(next.endDay == date("2026-11-17"))
    }

    @Test func uncompletingRecurringTaskDoesNotCreateAnother() {
        let task = repository.save(draft(repeatRule: .daily), to: nil)
        #expect(repository.setCompleted(task, false) == nil)
        #expect(repository.tasks.count == 1)
        #expect(task.repeatRule == .daily)
    }

    @Test func recurringTaskWithoutDateHasNoNextOccurrence() {
        let task = repository.save(draft(due: nil, repeatRule: .daily), to: nil)
        #expect(repository.setCompleted(task, true) == nil)
        #expect(repository.tasks.count == 1)
    }

    // MARK: - delete / restore

    @Test func deleteRemovesTaskSubtasksAndReminder() throws {
        let task = repository.save(draft(reminder: .atTime, subtasks: [subtask("A")]), to: nil)
        let id = task.id
        repository.delete(task)

        #expect(repository.tasks.isEmpty)
        #expect(try count(Subtask.self) == 0)
        #expect(reminders.calls.last == .cancel(taskID: id))
    }

    @Test func restoreRecreatesDeletedTaskWithAllFields() throws {
        repository.save(TaskListDraft(name: "Дом", colorHex: "#123456", symbolName: "house"), to: nil)
        let list = repository.lists[0]
        let task = repository.save(
            draft("Уборка", due: "2026-11-08 18:00", minutes: 90, reminder: .hourBefore, repeatRule: .weekly,
                  list: list, subtasks: [subtask("Пыль", done: true), subtask("Пол")]),
            to: nil
        )
        repository.setCompleted(task, false)
        let snapshot = TaskSnapshot(task)
        repository.delete(task)

        repository.restore(snapshot)

        let restored = try #require(repository.tasks.first)
        #expect(restored.id == snapshot.id)
        #expect(restored.title == "Уборка")
        #expect(restored.dueDate == date("2026-11-08 18:00"))
        #expect(restored.durationMinutes == 90)
        #expect(restored.reminder == .hourBefore)
        #expect(restored.repeatRule == .weekly)
        #expect(restored.list === list)
        #expect(restored.sortedSubtasks.map(\.title) == ["Пыль", "Пол"])
        #expect(restored.sortedSubtasks.map(\.isCompleted) == [true, false])
        #expect(restored.createdAt == snapshot.createdAt)
        #expect(restored.sortOrder == snapshot.sortOrder)
        #expect(reminders.lastFireDate(for: restored.id) == date("2026-11-08 17:00"))
    }

    @Test func restoreRevertsEditedTask() {
        let task = repository.save(draft("До", due: "2026-11-08 10:00"), to: nil)
        let snapshot = TaskSnapshot(task)
        repository.save(draft("После", due: "2026-11-10 15:00"), to: task)

        repository.restore(snapshot)

        #expect(repository.tasks.count == 1)
        #expect(task.title == "До")
        #expect(task.dueDate == date("2026-11-08 10:00"))
    }

    @Test func restoreBringsBackCompletionDate() {
        let task = repository.save(draft(), to: nil)
        repository.setCompleted(task, true)
        let snapshot = TaskSnapshot(task)
        clock.advance(minutes: 30)
        repository.setCompleted(task, false)

        repository.restore(snapshot)
        #expect(task.isCompleted)
        #expect(task.completedAt == date("2026-11-08 09:00"))
    }

    // MARK: - Остальные операции

    @Test func duplicateCopiesTaskAsOpenWithNewSubtasks() {
        let task = repository.save(draft("Отчёт", subtasks: [subtask("Черновик", done: true)], completed: true), to: nil)
        let copy = repository.duplicate(task)

        #expect(copy.id != task.id)
        #expect(copy.title == "Отчёт (копия)")
        #expect(!copy.isCompleted)
        #expect(copy.dueDate == task.dueDate)
        #expect(copy.sortedSubtasks.map(\.title) == ["Черновик"])
        // Текущее поведение: отметки подзадач копируются как есть.
        #expect(copy.sortedSubtasks.map(\.isCompleted) == [true])
        #expect(copy.subtasks.first?.id != task.subtasks.first?.id)
        #expect(repository.tasks.count == 2)
    }

    @Test func scheduleMakesTaskTimedSingleDay() {
        let task = repository.save(draft(due: "2026-11-08", minutes: 30, endDay: "2026-11-10", reminder: .atTime), to: nil)
        repository.schedule(task, at: date("2026-11-09 14:00"))

        #expect(task.dueDate == date("2026-11-09 14:00"))
        #expect(task.hasTime)
        #expect(task.endDay == nil)
        #expect(task.durationMinutes == 30)
        #expect(reminders.lastFireDate(for: task.id) == date("2026-11-09 14:00"))
    }

    @Test func setDurationChangesOnlyDuration() {
        let task = repository.save(draft(), to: nil)
        reminders.reset()
        repository.setDuration(task, minutes: 25)
        #expect(task.durationMinutes == 25)
        #expect(task.dueDate == date("2026-11-08 12:00"))
        #expect(reminders.calls.isEmpty)
    }

    @Test func setDaysOrdersRangeAndDropsTime() {
        let task = repository.save(draft(), to: nil)

        repository.setDays(task, start: date("2026-11-12 10:00"), end: date("2026-11-10 08:00"))
        #expect(task.dueDate == date("2026-11-10"))
        #expect(task.endDay == date("2026-11-12"))
        #expect(!task.hasTime)

        repository.setDays(task, start: date("2026-11-11"), end: date("2026-11-11 23:00"))
        #expect(task.dueDate == date("2026-11-11"))
        #expect(task.endDay == nil)
    }

    @Test func moveToTodayKeepsTime() {
        let task = repository.save(draft(due: "2026-11-05 14:30", reminder: .atTime), to: nil)
        repository.moveToToday(task)
        #expect(task.dueDate == date("2026-11-08 14:30"))
        #expect(task.updatedAt == clock.now)
        #expect(reminders.lastFireDate(for: task.id) == date("2026-11-08 14:30"))
    }

    // MARK: - Напоминания

    @Test func remindersFollowSettingsSwitch() {
        let task = repository.save(draft(reminder: .atTime), to: nil)
        #expect(reminders.lastFireDate(for: task.id) == date("2026-11-08 12:00"))

        repository.rescheduleReminders(enabled: false)
        #expect(reminders.calls.last == .reschedule(taskID: task.id, title: "Задача", fireDate: nil))

        let other = repository.save(draft("Другая", reminder: .atTime), to: nil)
        #expect(reminders.calls.last == .reschedule(taskID: other.id, title: "Другая", fireDate: nil))

        repository.rescheduleReminders(enabled: true)
        #expect(reminders.lastFireDate(for: task.id) == date("2026-11-08 12:00"))
        #expect(reminders.lastFireDate(for: other.id) == date("2026-11-08 12:00"))
    }

    @Test func pastReminderIsNotScheduled() {
        let task = repository.save(draft(due: "2026-11-08 08:00", reminder: .atTime), to: nil)
        #expect(reminders.calls.last == .reschedule(taskID: task.id, title: "Задача", fireDate: nil))
    }

    // MARK: - Категории

    @Test func savesAndEditsCategories() {
        repository.save(TaskListDraft(name: "Работа", colorHex: "#111111", symbolName: "a"), to: nil)
        repository.save(TaskListDraft(name: "Дом", colorHex: "#222222", symbolName: "b"), to: nil)
        #expect(repository.lists.map(\.name) == ["Работа", "Дом"])
        #expect(repository.lists[1].sortOrder == repository.lists[0].sortOrder + 1)

        let work = repository.lists[0]
        repository.save(TaskListDraft(name: "Офис", colorHex: "#333333", symbolName: "c"), to: work)
        #expect(repository.lists.count == 2)
        #expect(work.name == "Офис")
        #expect(work.colorHex == "#333333")
        #expect(work.symbolName == "c")
    }

    @Test func deletingCategoryDeletesItsTasksAndReminders() throws {
        repository.save(TaskListDraft(name: "Работа", colorHex: "#111111", symbolName: "a"), to: nil)
        let list = repository.lists[0]
        let inList = repository.save(draft("В списке", reminder: .atTime, list: list), to: nil)
        let outside = repository.save(draft("Без списка"), to: nil)
        let id = inList.id

        repository.delete(list)

        #expect(repository.lists.isEmpty)
        // Каскад: задачи категории удаляются вместе с ней.
        #expect(repository.tasks.map(\.id) == [outside.id])
        #expect(reminders.calls.contains(.cancel(taskID: id)))
    }

    @Test func insertAddsPrebuiltModels() {
        repository.insert([TaskItem(title: "Б", sortOrder: 2), TaskItem(title: "А", sortOrder: 1)])
        repository.insert([TaskList(name: "Список")])
        #expect(repository.tasks.map(\.title) == ["А", "Б"])
        #expect(repository.lists.map(\.name) == ["Список"])
    }

    @Test func newRepositoryLoadsExistingData() {
        repository.save(draft("Сохранённая"), to: nil)
        let reopened = SwiftDataRepository(context: container.mainContext, clock: clock, reminders: reminders)
        #expect(reopened.tasks.map(\.title) == ["Сохранённая"])
    }
}
