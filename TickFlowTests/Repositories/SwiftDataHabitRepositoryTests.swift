import Foundation
import SwiftData
import Testing
@testable import TickFlow

@MainActor
struct SwiftDataHabitRepositoryTests {
    let container: ModelContainer
    let clock = FixedClock("2026-11-08 09:00")
    let reminders = FakeReminderScheduler()
    let repository: SwiftDataHabitRepository

    init() throws {
        container = try makeInMemoryContainer()
        repository = SwiftDataHabitRepository(
            context: container.mainContext,
            clock: clock,
            calendar: TestCalendar.moscow,
            reminders: reminders
        )
    }

    private func draft(
        _ name: String = "Чтение",
        kind: HabitKind = .check,
        target: Double = 1,
        frequency: HabitFrequency = .daily,
        weekdays: [Int] = [6, 2, 4],
        reminder: Bool = false,
        minute: Int = 540
    ) -> HabitDraft {
        HabitDraft(
            name: name, symbolName: "book", colorHex: "#5B5BD6", kind: kind, target: target, unit: "стр.",
            step: 5, frequency: frequency, weekdays: weekdays, timesPerWeek: 3,
            reminderEnabled: reminder, reminderMinute: minute
        )
    }

    private func logCount() throws -> Int {
        try container.mainContext.fetchCount(FetchDescriptor<HabitLog>())
    }

    // MARK: - save

    @Test func newHabitStartsTodayWithGrowingSortOrder() {
        let first = repository.save(draft("Первая"), to: nil)
        let second = repository.save(draft("Вторая"), to: nil)

        #expect(repository.habits.map(\.name) == ["Первая", "Вторая"])
        #expect(first.startDate == date("2026-11-08"))
        #expect(second.sortOrder == first.sortOrder + 1)
    }

    @Test func checkHabitAlwaysHasTargetOne() {
        let habit = repository.save(draft(kind: .check, target: 7), to: nil)
        #expect(habit.target == 1)

        repository.save(draft(kind: .amount, target: 7), to: habit)
        #expect(habit.target == 7)
        #expect(habit.kind == .amount)
    }

    @Test func weekdaysAreSortedOnlyForSpecificDays() {
        let specific = repository.save(draft(frequency: .specificDays, weekdays: [6, 2, 4]), to: nil)
        #expect(specific.weekdays == [2, 4, 6])

        let daily = repository.save(draft(frequency: .daily, weekdays: [6, 2]), to: nil)
        #expect(daily.weekdays == [1, 2, 3, 4, 5, 6, 7])
    }

    @Test func editingKeepsStartDate() {
        let habit = repository.save(draft("Старое"), to: nil)
        clock.advance(days: 3)
        repository.save(draft("Новое"), to: habit)

        #expect(repository.habits.count == 1)
        #expect(habit.name == "Новое")
        #expect(habit.startDate == date("2026-11-08"))
    }

    // MARK: - Напоминания

    @Test func dailyReminderHasNoWeekdays() {
        let habit = repository.save(draft("Вода", reminder: true, minute: 600), to: nil)
        #expect(reminders.calls.last == .scheduleHabit(id: habit.id, name: "Вода", minute: 600, weekdays: nil))
    }

    @Test func specificDaysReminderUsesWeekdays() {
        let habit = repository.save(draft("Спорт", frequency: .specificDays, weekdays: [6, 2], reminder: true), to: nil)
        #expect(reminders.calls.last == .scheduleHabit(id: habit.id, name: "Спорт", minute: 540, weekdays: [2, 6]))
    }

    @Test func disabledReminderIsCancelled() {
        let habit = repository.save(draft(reminder: true), to: nil)
        repository.save(draft(reminder: false), to: habit)
        #expect(reminders.calls.last == .cancelHabit(id: habit.id))
    }

    @Test func globalSwitchCancelsAndRestoresReminders() {
        let withReminder = repository.save(draft("С напоминанием", reminder: true), to: nil)
        let without = repository.save(draft("Без", reminder: false), to: nil)
        reminders.reset()

        repository.rescheduleReminders(enabled: false)
        #expect(Set(reminders.calls) == [.cancelHabit(id: withReminder.id), .cancelHabit(id: without.id)])

        reminders.reset()
        repository.rescheduleReminders(enabled: true)
        #expect(reminders.calls.contains(.scheduleHabit(id: withReminder.id, name: "С напоминанием", minute: 540, weekdays: nil)))
        #expect(reminders.calls.contains(.cancelHabit(id: without.id)))
    }

    // MARK: - delete

    @Test func deleteRemovesHabitLogsAndReminder() throws {
        let habit = repository.save(draft(), to: nil)
        repository.setValue(1, for: habit, on: date("2026-11-07"))
        let id = habit.id

        repository.delete(habit)

        #expect(repository.habits.isEmpty)
        #expect(try logCount() == 0)
        #expect(reminders.calls.last == .cancelHabit(id: id))
    }

    // MARK: - Отметки

    @Test func oneLogPerDayIsUpdated() throws {
        let habit = repository.save(draft(kind: .amount, target: 10), to: nil)
        repository.setValue(3, for: habit, on: date("2026-11-08 08:00"))
        repository.setValue(7, for: habit, on: date("2026-11-08 21:00"))

        #expect(try logCount() == 1)
        let log = try #require(habit.log(on: date("2026-11-08"), calendar: TestCalendar.moscow))
        #expect(log.value == 7)
        #expect(log.day == date("2026-11-08"))
    }

    @Test func separateDaysHaveSeparateLogs() throws {
        let habit = repository.save(draft(), to: nil)
        repository.setValue(1, for: habit, on: date("2026-11-07"))
        repository.setValue(1, for: habit, on: date("2026-11-08"))
        #expect(try logCount() == 2)
        #expect(habit.logs.count == 2)
    }

    @Test func zeroOrNegativeValueRemovesLog() throws {
        let habit = repository.save(draft(), to: nil)
        repository.setValue(1, for: habit, on: date("2026-11-08"))
        repository.setValue(0, for: habit, on: date("2026-11-08"))
        #expect(try logCount() == 0)

        repository.setValue(-5, for: habit, on: date("2026-11-08"))
        #expect(try logCount() == 0)
    }

    @Test func settingValueClearsSkip() throws {
        let habit = repository.save(draft(), to: nil)
        repository.setSkipped(true, for: habit, on: date("2026-11-08"))
        repository.setValue(1, for: habit, on: date("2026-11-08"))

        let log = try #require(habit.log(on: date("2026-11-08"), calendar: TestCalendar.moscow))
        #expect(!log.isSkipped)
        #expect(log.value == 1)
    }

    @Test func skippingResetsValue() throws {
        let habit = repository.save(draft(kind: .amount, target: 10), to: nil)
        repository.setValue(4, for: habit, on: date("2026-11-08"))
        repository.setSkipped(true, for: habit, on: date("2026-11-08"))

        // Текущее поведение: пропуск обнуляет внесённое значение.
        let log = try #require(habit.log(on: date("2026-11-08"), calendar: TestCalendar.moscow))
        #expect(log.isSkipped)
        #expect(log.value == 0)
        #expect(try logCount() == 1)
    }

    @Test func unskippingEmptyDayRemovesLog() throws {
        let habit = repository.save(draft(), to: nil)
        repository.setSkipped(true, for: habit, on: date("2026-11-08"))
        repository.setSkipped(false, for: habit, on: date("2026-11-08"))
        #expect(try logCount() == 0)
    }

    @Test func insertAndReload() {
        let habit = Habit(name: "Готовая", symbolName: "leaf", colorHex: "#000000", kind: .check,
                          target: 1, unit: "", step: 1, frequency: .daily)
        repository.insert([habit])
        #expect(repository.habits.map(\.name) == ["Готовая"])

        let reopened = SwiftDataHabitRepository(context: container.mainContext, clock: clock, reminders: reminders)
        #expect(reopened.habits.map(\.name) == ["Готовая"])
    }
}
