import Foundation

/// Значения привычки для сохранения: редактор меняет черновик, а не модель.
struct HabitDraft {
    var name: String
    var symbolName: String
    var colorHex: String
    var kind: HabitKind
    var target: Double
    var unit: String
    var step: Double
    var frequency: HabitFrequency
    var weekdays: [Int]
    var timesPerWeek: Int
    var reminderEnabled: Bool
    var reminderMinute: Int
}

/// Доступ к привычкам. `habits` наблюдаем: экран обновится после любого изменения.
@MainActor
protocol HabitRepository: AnyObject {
    /// Все привычки по `sortOrder`.
    var habits: [Habit] { get }

    func insert(_ habits: [Habit])
    @discardableResult
    func save(_ draft: HabitDraft, to habit: Habit?) -> Habit
    func delete(_ habit: Habit)
    /// Записывает значение за день. Значение 0 без пропуска удаляет отметку.
    func setValue(_ value: Double, for habit: Habit, on day: Date)
    func setSkipped(_ isSkipped: Bool, for habit: Habit, on day: Date)
    /// Перепланирует напоминания всех привычек (например, после смены настроек).
    func rescheduleReminders(enabled: Bool)
}
