import Foundation

/// Наполняет базу при первом запуске (и по кнопке «Загрузить пример»), чтобы приложение не открывалось пустым.
enum SeedService {

    @MainActor
    static func seedIfNeeded(tasks: any TaskRepository, lists: any TaskListRepository, habits: any HabitRepository) {
        guard lists.lists.isEmpty, tasks.tasks.isEmpty else { return }
        seedSample(tasks: tasks, lists: lists, habits: habits)
    }

    /// Пример данных из макета, относительно сегодняшнего дня.
    @MainActor
    static func seedSample(tasks: any TaskRepository, lists: any TaskListRepository, habits: any HabitRepository) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        let categories = lists.lists.isEmpty ? makeCategories() : []
        lists.insert(categories)
        let all = lists.lists
        func category(_ name: String) -> TaskList? { all.first { $0.name == name } ?? all.first }

        let work = category(L10n.Sample.work), personal = category(L10n.Sample.personal), health = category(L10n.Sample.health)
        let errands = category(L10n.Sample.errands), learning = category(L10n.Sample.learning)

        var order = (tasks.tasks.map(\.sortOrder).max() ?? 0) + 1
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today) ?? today }
        func task(
            _ title: String, _ list: TaskList?, day offset: Int?, start: Int? = nil, end: Int? = nil,
            endDay: Int? = nil, priority: Priority = .none, done: Bool = false, notes: String = "",
            repeatRule: RepeatRule = .never, reminder: ReminderOption = .none, subtasks: [(String, Bool)] = []
        ) -> TaskItem {
            var due: Date?
            if let offset {
                due = start.map { calendar.date(byAdding: .minute, value: $0, to: day(offset)) ?? day(offset) } ?? day(offset)
            }
            let item = TaskItem(
                title: title, notes: notes, dueDate: due, hasTime: start != nil,
                durationMinutes: start.flatMap { s in end.map { $0 - s } } ?? 60,
                priority: priority, list: list, sortOrder: order
            )
            order += 1
            item.endDay = endDay.map(day)
            item.repeatRule = repeatRule
            item.reminder = reminder
            item.subtasks = subtasks.enumerated().map { Subtask(title: $1.0, isCompleted: $1.1, sortOrder: $0) }
            if done {
                item.setCompleted(true)
                item.completedAt = due ?? .now
            }
            // Задача создана за пару дней до срока; будущие — в разные дни последних двух недель.
            let created = (due ?? today).addingTimeInterval(-2 * 86_400)
            let spread = Date.now.addingTimeInterval(-Double(order % 14) * 86_400)
            item.createdAt = min(created, spread)
            return item
        }

        tasks.insert([
            task(L10n.Sample.teamStandup, work, day: 0, start: 540, end: 570, repeatRule: .weekdays, reminder: .tenMinutesBefore),
            task(L10n.Sample.designReview, work, day: 0, start: 660, end: 750, priority: .medium,
                 notes: L10n.Sample.designReviewNotes, reminder: .tenMinutesBefore,
                 subtasks: [(L10n.Sample.exportMockups, true), (L10n.Sample.prepareAgenda, true), (L10n.Sample.collectFeedback, false)]),
            task(L10n.Sample.quarterReport, work, day: 0, start: 690, end: 780, priority: .high),
            task(L10n.Sample.lunchMia, personal, day: 0, start: 810, end: 870),
            task(L10n.Sample.gymUpper, health, day: 0, start: 1080, end: 1140, repeatRule: .weekly),
            task(L10n.Sample.payRent, errands, day: 0, priority: .medium, reminder: .atTime),
            task(L10n.Sample.dentist, personal, day: 1, start: 600, end: 660, reminder: .hourBefore),
            task(L10n.Sample.designConference, work, day: 1, endDay: 3, notes: L10n.Sample.designConferenceNotes),
            task(L10n.Sample.productSync, work, day: -1, start: 840, end: 900, done: true),
            task(L10n.Sample.callBank, personal, day: -1, start: 960, end: 990, priority: .low),
            task(L10n.Sample.sprintPlanning, work, day: -2, start: 600, end: 690, done: true),
            task(L10n.Sample.spanishLesson, learning, day: -3, start: 1140, end: 1200, done: true),
            task(L10n.Sample.groceries, errands, day: 2, start: 600, end: 660,
                 subtasks: [(L10n.Sample.oatMilk, false), (L10n.Sample.coffeeBeans, false)]),
            task(L10n.Sample.run10k, health, day: 3, start: 480, end: 570),
            task(L10n.Sample.oneOnOneAlex, work, day: 4, start: 900, end: 930, repeatRule: .weekly),
            task(L10n.Sample.readThinking, learning, day: nil),
            task(L10n.Sample.renewPassport, errands, day: nil, priority: .low),
            task(L10n.Sample.updatePortfolio, work, day: 6),
            task(L10n.Sample.buyTickets, personal, day: -4, priority: .medium),
            task(L10n.Sample.quarterPlanning, work, day: 8, start: 600, end: 720),
            task(L10n.Sample.momBirthday, personal, day: 12),
            task(L10n.Sample.yoga, health, day: -6, start: 1080, end: 1140, done: true),
            task(L10n.Sample.carService, errands, day: -8, start: 540, end: 600, done: true),
            task(L10n.Sample.workshopPrep, work, day: 7, start: 840, end: 960),
            task(L10n.Sample.codeReview, work, day: -2, start: 840, end: 900, done: true),
            task(L10n.Sample.pilates, health, day: -1, start: 1110, end: 1170, done: true),
        ])
        tasks.insert(makeHistory(today: today, calendar: calendar, lists: [work, personal, health, errands, learning],
                                 firstOrder: order))

        guard habits.habits.isEmpty else { return }
        habits.insert(makeHabits(today: today, calendar: calendar))
    }

    private static func makeCategories() -> [TaskList] {
        [
            TaskList(name: L10n.Sample.work, colorHex: "#5B5BD6", symbolName: "briefcase", sortOrder: 0),
            TaskList(name: L10n.Sample.personal, colorHex: "#2A9792", symbolName: "house", sortOrder: 1),
            TaskList(name: L10n.Sample.health, colorHex: "#399E62", symbolName: "heart", sortOrder: 2),
            TaskList(name: L10n.Sample.errands, colorHex: "#CF8526", symbolName: "cart", sortOrder: 3),
            TaskList(name: L10n.Sample.learning, colorHex: "#BE5A96", symbolName: "graduationcap", sortOrder: 4),
        ]
    }

    /// Привычки из макета с историей за ~4 месяца. История детерминированная,
    /// чтобы графики выглядели одинаково при каждом запуске.
    private static func makeHabits(today: Date, calendar: Calendar) -> [Habit] {
        struct Spec {
            let name, symbol, color: String
            let kind: HabitKind
            let target, step: Double
            let unit: String
            let frequency: HabitFrequency
            let weekdays: [Int]
            let streak: Int
            let todayValue: Double
            let reminderMinute: Int
        }
        let specs = [
            Spec(name: L10n.Habits.suggestionReading, symbol: "book", color: "#5B5BD6", kind: .duration, target: 20, step: 5, unit: L10n.Format.minutesUnit,
                 frequency: .daily, weekdays: Array(1...7), streak: 12, todayValue: 10, reminderMinute: 1290),
            Spec(name: L10n.Habits.suggestionWater, symbol: "drop", color: "#2A9792", kind: .amount, target: 2, step: 0.25, unit: L10n.Habits.unitLiters,
                 frequency: .daily, weekdays: Array(1...7), streak: 5, todayValue: 1.25, reminderMinute: 600),
            Spec(name: L10n.Habits.suggestionMeditation, symbol: "leaf", color: "#399E62", kind: .duration, target: 10, step: 5, unit: L10n.Format.minutesUnit,
                 frequency: .daily, weekdays: Array(1...7), streak: 30, todayValue: 10, reminderMinute: 450),
            Spec(name: L10n.Habits.suggestionWorkout, symbol: "dumbbell", color: "#CF8526", kind: .check, target: 1, step: 1, unit: "",
                 frequency: .specificDays, weekdays: [2, 4, 6], streak: 8, todayValue: 0, reminderMinute: 1110),
            Spec(name: L10n.Sample.spanish, symbol: "lightbulb", color: "#BE5A96", kind: .check, target: 1, step: 1, unit: "",
                 frequency: .specificDays, weekdays: [2, 3, 4, 5, 6], streak: 3, todayValue: 0, reminderMinute: 1200),
        ]

        let historyDays = 120
        let start = calendar.date(byAdding: .day, value: -historyDays, to: today) ?? today

        return specs.enumerated().map { index, spec in
            let habit = Habit(
                name: spec.name, symbolName: spec.symbol, colorHex: spec.color, kind: spec.kind,
                target: spec.target, unit: spec.unit, step: spec.step, frequency: spec.frequency,
                weekdays: spec.weekdays, reminderEnabled: true, reminderMinute: spec.reminderMinute,
                startDate: start, sortOrder: index
            )

            var logs: [HabitLog] = []
            if spec.todayValue > 0 { logs.append(HabitLog(day: today, value: spec.todayValue)) }

            var scheduledCount = 0
            for offset in 1...historyDays {
                guard let day = calendar.date(byAdding: .day, value: -offset, to: today),
                      spec.weekdays.contains(calendar.component(.weekday, from: day)) else { continue }
                scheduledCount += 1
                let noise = pseudoRandom(index * 97 + offset * 13)
                if scheduledCount <= spec.streak {
                    // Один пропуск внутри серии: показывает, что пропуск её не прерывает.
                    logs.append(scheduledCount == 4 && index == 0
                        ? HabitLog(day: day, isSkipped: true)
                        : HabitLog(day: day, value: spec.target))
                } else if scheduledCount == spec.streak + 1 {
                    continue // пропущенный день, с которого началась текущая серия
                } else if noise < 0.74 {
                    logs.append(HabitLog(day: day, value: spec.target))
                } else if noise < 0.8 {
                    logs.append(HabitLog(day: day, isSkipped: true))
                }
            }
            habit.logs = logs
            return habit
        }
    }

    /// Выполненные задачи за прошлые пять недель: чтобы в аналитике были графики и сравнение периодов.
    private static func makeHistory(today: Date, calendar: Calendar, lists: [TaskList?], firstOrder: Int) -> [TaskItem] {
        let titles = [
            [L10n.Sample.reviewMockups, L10n.Sample.teamSync, L10n.Sample.replyEmails, L10n.Sample.preparePresentation, L10n.Sample.codeReview],
            [L10n.Sample.callParents, L10n.Sample.sortPhotos, L10n.Sample.doctorAppointment],
            [L10n.Sample.run, L10n.Sample.stretching, L10n.Sample.pool],
            [L10n.Sample.buyGroceries, L10n.Sample.payBills, L10n.Sample.pickUpParcel],
            [L10n.Sample.spanishLesson, L10n.Sample.bookChapter, L10n.Sample.onlineCourse],
        ]
        var items: [TaskItem] = []
        var order = firstOrder
        for offset in 2...42 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            let isWeekend = weekday == 1 || weekday == 7
            let count = isWeekend ? 1 : 1 + Int(pseudoRandom(offset * 7) * 2.4)
            for index in 0..<count {
                let noise = pseudoRandom(offset * 31 + index * 5)
                let listIndex = isWeekend ? 1 + index % 4 : (noise < 0.55 ? 0 : Int(noise * 10) % 5)
                let pool = titles[listIndex]
                let start = (isWeekend ? 600 : 780) + index * 180 + Int(noise * 3) * 30
                guard let due = calendar.date(byAdding: .minute, value: start, to: day) else { continue }
                let item = TaskItem(
                    title: pool[(offset + index) % pool.count], dueDate: due, hasTime: true,
                    durationMinutes: 60, list: lists[listIndex], sortOrder: order
                )
                order += 1
                item.createdAt = due.addingTimeInterval(-Double(1 + index) * 86_400)
                item.setCompleted(true)
                item.completedAt = due.addingTimeInterval(45 * 60)
                items.append(item)
            }
        }
        return items
    }

    private static func pseudoRandom(_ seed: Int) -> Double {
        let x = sin(Double(seed) * 12.9898) * 43758.5453
        return x - x.rounded(.down)
    }
}
