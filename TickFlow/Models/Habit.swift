import Foundation
import SwiftData

/// Как отмечается привычка.
enum HabitKind: Int, CaseIterable, Identifiable, Codable {
    /// Выполнено / не выполнено.
    case check = 0
    /// Количество: литры, страницы, разы.
    case amount = 1
    /// Минуты.
    case duration = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .check: L10n.HabitKind.check
        case .amount: L10n.HabitKind.amount
        case .duration: L10n.Common.time
        }
    }
}

/// Как часто нужно выполнять привычку.
enum HabitFrequency: Int, CaseIterable, Identifiable, Codable {
    case daily = 0
    /// Конкретные дни недели (`Habit.weekdays`).
    case specificDays = 1
    /// N раз в неделю, в любые дни (`Habit.timesPerWeek`).
    case weeklyGoal = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .daily: L10n.Common.everyDay
        case .specificDays: L10n.HabitFrequency.specificDays
        case .weeklyGoal: L10n.HabitFrequency.weeklyGoal
        }
    }
}

@Model
final class Habit {
    var id: UUID = UUID()
    var name: String = ""
    var symbolName: String = "book"
    var colorHex: String = "#5B5BD6"
    var kindRaw: Int = 0
    /// Цель на день. Для `check` всегда 1.
    var target: Double = 1
    /// Единица для `amount`: "раз", "л", "стр.". Для `duration` — минуты.
    var unit: String = ""
    /// На сколько меняется значение по нажатию на кольцо.
    var step: Double = 1
    var frequencyRaw: Int = 0
    /// Дни недели по `Calendar.component(.weekday)`: 1 — воскресенье … 7 — суббота.
    var weekdays: [Int] = [1, 2, 3, 4, 5, 6, 7]
    var timesPerWeek: Int = 3
    var reminderEnabled: Bool = false
    /// Минуты от полуночи.
    var reminderMinute: Int = 540
    var startDate: Date = Date.now
    var sortOrder: Int = 0
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \HabitLog.habit)
    var logs: [HabitLog] = []

    init(
        name: String,
        symbolName: String,
        colorHex: String,
        kind: HabitKind,
        target: Double,
        unit: String,
        step: Double,
        frequency: HabitFrequency,
        weekdays: [Int] = [1, 2, 3, 4, 5, 6, 7],
        timesPerWeek: Int = 3,
        reminderEnabled: Bool = false,
        reminderMinute: Int = 540,
        startDate: Date = .now,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.kindRaw = kind.rawValue
        self.target = target
        self.unit = unit
        self.step = step
        self.frequencyRaw = frequency.rawValue
        self.weekdays = weekdays
        self.timesPerWeek = timesPerWeek
        self.reminderEnabled = reminderEnabled
        self.reminderMinute = reminderMinute
        self.startDate = startDate
        self.sortOrder = sortOrder
        self.createdAt = .now
    }

    var kind: HabitKind {
        get { HabitKind(rawValue: kindRaw) ?? .check }
        set { kindRaw = newValue.rawValue }
    }

    var frequency: HabitFrequency {
        get { HabitFrequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    /// Запланирована ли привычка на этот день. Для недельной цели — любой день.
    func isScheduled(on day: Date, calendar: Calendar = .current) -> Bool {
        switch frequency {
        case .daily, .weeklyGoal: true
        case .specificDays: weekdays.contains(calendar.component(.weekday, from: day))
        }
    }

    func log(on day: Date, calendar: Calendar = .current) -> HabitLog? {
        logs.first { calendar.isDate($0.day, inSameDayAs: day) }
    }
}

/// Отметка привычки за один день.
@Model
final class HabitLog {
    var id: UUID = UUID()
    /// Начало дня.
    var day: Date = Date.now
    var value: Double = 0
    /// Пропуск по желанию пользователя: серия не прерывается.
    var isSkipped: Bool = false
    var habit: Habit?

    init(day: Date, value: Double = 0, isSkipped: Bool = false) {
        self.id = UUID()
        self.day = day
        self.value = value
        self.isSkipped = isSkipped
    }
}
