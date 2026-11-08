import Foundation
import Testing
@testable import TickFlow

/// Проверяет тестовую инфраструктуру и то, что время, календарь и напоминания действительно внедряются.
@MainActor
struct InfrastructureTests {

    @Test func hostAppDetectsTestRun() {
        #expect(LaunchEnvironment.isRunningUnitTests)
    }

    @Test func dateFactoryUsesGivenCalendar() {
        let value = date("2026-11-08 09:30")
        let parts = TestCalendar.moscow.dateComponents([.year, .month, .day, .hour, .minute], from: value)
        #expect(parts == DateComponents(year: 2026, month: 11, day: 8, hour: 9, minute: 30))
        #expect(date("2026-11-08") == TestCalendar.moscow.startOfDay(for: value))
    }

    @Test func fixedClockAdvances() {
        let clock = FixedClock("2026-11-08 23:50")
        clock.advance(minutes: 20)
        #expect(clock.now == date("2026-11-09 00:10"))
        clock.advance(days: 1)
        #expect(clock.now == date("2026-11-10 00:10"))
    }

    @Test func taskOverdueFollowsInjectedNow() {
        let task = TaskItem(title: "Отчёт", dueDate: date("2026-11-08"))
        #expect(!task.isOverdue(now: date("2026-11-08 23:59"), calendar: TestCalendar.moscow))
        #expect(task.isOverdue(now: date("2026-11-09 00:00"), calendar: TestCalendar.moscow))
    }

    @Test func displayFormatterTodayFollowsClock() {
        let clock = FixedClock("2026-11-08 15:00")
        let format = DisplayFormatter(settings: AppSettings(), base: TestCalendar.moscow, clock: clock)
        #expect(format.today == date("2026-11-08"))
        #expect(format.isToday(date("2026-11-08 01:00")))

        clock.advance(days: 1)
        #expect(format.today == date("2026-11-09"))
    }

    @Test func repositoryUsesInjectedClockAndScheduler() throws {
        let container = try makeInMemoryContainer()
        let clock = FixedClock("2026-11-08 09:00")
        let reminders = FakeReminderScheduler()
        let repository = SwiftDataRepository(
            context: container.mainContext,
            clock: clock,
            calendar: TestCalendar.moscow,
            reminders: reminders
        )

        let draft = TaskDraft(
            title: "Созвон", notes: "", dueDate: date("2026-11-08 12:00"), hasTime: true,
            durationMinutes: 30, endDay: nil, priority: .none, reminder: .tenMinutesBefore,
            repeatRule: .never, list: nil, subtasks: []
        )
        let task = repository.save(draft, to: nil)

        #expect(repository.tasks.count == 1)
        #expect(task.updatedAt == clock.now)
        #expect(reminders.lastFireDate(for: task.id) == date("2026-11-08 11:50"))

        // Напоминание уже в прошлом относительно часов — снимается.
        clock.now = date("2026-11-08 11:55")
        repository.rescheduleReminders(enabled: true)
        #expect(reminders.calls.last == .reschedule(taskID: task.id, title: "Созвон", fireDate: nil))

        repository.delete(task)
        #expect(reminders.calls.last == .cancel(taskID: task.id))
        #expect(repository.tasks.isEmpty)
    }

    @Test func settingsRepositoryUsesIsolatedDefaults() {
        let defaults = makeIsolatedDefaults()
        let repository = UserDefaultsSettingsRepository(defaults: defaults)
        repository.update { $0.uses24HourTime = false }

        #expect(UserDefaultsSettingsRepository(defaults: defaults).settings.uses24HourTime == false)
        #expect(defaults !== UserDefaults.standard)
    }
}
