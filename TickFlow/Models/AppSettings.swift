import Foundation

enum AppTheme: Int, CaseIterable, Identifiable, Codable {
    case system = 0
    case light = 1
    case dark = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .system: "Как в системе"
        case .light: "Светлая"
        case .dark: "Тёмная"
        }
    }
}

/// Пользовательские настройки. Значения по умолчанию совпадают с макетом.
struct AppSettings: Codable, Equatable {
    /// 1 — воскресенье, 2 — понедельник (как `Calendar.firstWeekday`).
    var firstWeekday = 2
    var defaultCalendarMode: CalendarMode = .week
    /// Вид, выбранный в календаре последним. Открывается при следующем запуске.
    var lastCalendarMode: CalendarMode?
    var uses24HourTime = true
    var defaultTaskDuration = 60
    var theme: AppTheme = .system
    var taskRemindersEnabled = true
    var defaultReminder: ReminderOption = .tenMinutesBefore
    var habitRemindersEnabled = true
    var allowsRestDays = true
    var skippedDaysKeepStreak = true
    var workdayStartHour = 9
    var workdayEndHour = 18
    var hasCompletedOnboarding = false

    init() {}

    /// Новые поля не ломают старые сохранения: отсутствующие ключи берутся по умолчанию.
    init(from decoder: Decoder) throws {
        let defaults = AppSettings()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        firstWeekday = try c.decodeIfPresent(Int.self, forKey: .firstWeekday) ?? defaults.firstWeekday
        defaultCalendarMode = try c.decodeIfPresent(CalendarMode.self, forKey: .defaultCalendarMode) ?? defaults.defaultCalendarMode
        lastCalendarMode = try c.decodeIfPresent(CalendarMode.self, forKey: .lastCalendarMode)
        uses24HourTime = try c.decodeIfPresent(Bool.self, forKey: .uses24HourTime) ?? defaults.uses24HourTime
        defaultTaskDuration = try c.decodeIfPresent(Int.self, forKey: .defaultTaskDuration) ?? defaults.defaultTaskDuration
        theme = try c.decodeIfPresent(AppTheme.self, forKey: .theme) ?? defaults.theme
        taskRemindersEnabled = try c.decodeIfPresent(Bool.self, forKey: .taskRemindersEnabled) ?? defaults.taskRemindersEnabled
        defaultReminder = try c.decodeIfPresent(ReminderOption.self, forKey: .defaultReminder) ?? defaults.defaultReminder
        habitRemindersEnabled = try c.decodeIfPresent(Bool.self, forKey: .habitRemindersEnabled) ?? defaults.habitRemindersEnabled
        allowsRestDays = try c.decodeIfPresent(Bool.self, forKey: .allowsRestDays) ?? defaults.allowsRestDays
        skippedDaysKeepStreak = try c.decodeIfPresent(Bool.self, forKey: .skippedDaysKeepStreak) ?? defaults.skippedDaysKeepStreak
        workdayStartHour = try c.decodeIfPresent(Int.self, forKey: .workdayStartHour) ?? defaults.workdayStartHour
        workdayEndHour = try c.decodeIfPresent(Int.self, forKey: .workdayEndHour) ?? defaults.workdayEndHour
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? defaults.hasCompletedOnboarding
    }
}
