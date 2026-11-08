import Foundation
import Observation
import OSLog
import SwiftData

/// Привычки и их отметки в SwiftData. Работает с тем же контекстом, что и задачи.
@MainActor
@Observable
final class SwiftDataHabitRepository: HabitRepository {
    private(set) var habits: [Habit] = []

    @ObservationIgnored var remindersEnabled = true

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let clock: any AppClock
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let reminders: any ReminderScheduling
    @ObservationIgnored private let logger = Logger(subsystem: "com.ahito.TickFlow", category: "HabitRepository")

    init(
        context: ModelContext,
        clock: any AppClock = SystemClock(),
        calendar: Calendar = .current,
        reminders: any ReminderScheduling = SystemReminderScheduler()
    ) {
        self.context = context
        self.clock = clock
        self.calendar = calendar
        self.reminders = reminders
        reload()
    }

    func insert(_ habits: [Habit]) {
        habits.forEach(context.insert)
        commit()
    }

    @discardableResult
    func save(_ draft: HabitDraft, to habit: Habit?) -> Habit {
        let item: Habit
        if let habit {
            item = habit
        } else {
            item = Habit(
                name: draft.name, symbolName: draft.symbolName, colorHex: draft.colorHex,
                kind: draft.kind, target: draft.target, unit: draft.unit, step: draft.step,
                frequency: draft.frequency, startDate: calendar.startOfDay(for: clock.now),
                sortOrder: (habits.map(\.sortOrder).max() ?? 0) + 1
            )
            context.insert(item)
        }
        item.name = draft.name
        item.symbolName = draft.symbolName
        item.colorHex = draft.colorHex
        item.kind = draft.kind
        item.target = draft.kind == .check ? 1 : draft.target
        item.unit = draft.unit
        item.step = draft.step
        item.frequency = draft.frequency
        item.weekdays = draft.frequency == .specificDays ? draft.weekdays.sorted() : [1, 2, 3, 4, 5, 6, 7]
        item.timesPerWeek = draft.timesPerWeek
        item.reminderEnabled = draft.reminderEnabled
        item.reminderMinute = draft.reminderMinute
        commit()
        updateReminder(for: item)
        return item
    }

    func delete(_ habit: Habit) {
        reminders.cancelHabit(id: habit.id)
        context.delete(habit)
        commit()
    }

    func setValue(_ value: Double, for habit: Habit, on day: Date) {
        let log = existingOrNewLog(for: habit, on: day)
        log.value = max(0, value)
        log.isSkipped = false
        if log.value == 0 { context.delete(log) }
        commit()
    }

    func setSkipped(_ isSkipped: Bool, for habit: Habit, on day: Date) {
        let log = existingOrNewLog(for: habit, on: day)
        log.isSkipped = isSkipped
        if isSkipped { log.value = 0 }
        if !isSkipped && log.value == 0 { context.delete(log) }
        commit()
    }

    func rescheduleReminders(enabled: Bool) {
        remindersEnabled = enabled
        habits.forEach(updateReminder)
    }

    // MARK: - Внутреннее

    private func existingOrNewLog(for habit: Habit, on day: Date) -> HabitLog {
        if let log = habit.log(on: day, calendar: calendar) { return log }
        let log = HabitLog(day: calendar.startOfDay(for: day))
        log.habit = habit
        context.insert(log)
        return log
    }

    private func updateReminder(for habit: Habit) {
        guard remindersEnabled, habit.reminderEnabled else {
            reminders.cancelHabit(id: habit.id)
            return
        }
        reminders.scheduleHabit(
            id: habit.id,
            name: habit.name,
            minute: habit.reminderMinute,
            weekdays: habit.frequency == .specificDays ? habit.weekdays : nil
        )
    }

    private func commit() {
        do {
            try context.save()
        } catch {
            logger.error("Не удалось сохранить привычки: \(error.localizedDescription)")
        }
        reload()
    }

    private func reload() {
        do {
            habits = try context.fetch(
                FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)])
            )
        } catch {
            logger.error("Не удалось загрузить привычки: \(error.localizedDescription)")
        }
    }
}
