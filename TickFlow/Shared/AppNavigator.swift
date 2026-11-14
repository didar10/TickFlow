import Foundation
import Observation

/// Вкладки приложения в порядке таб-бара.
enum AppTab: Hashable, CaseIterable {
    case tasks, calendar, habits, profile

    var title: String {
        switch self {
        case .tasks: L10n.Tab.tasks
        case .calendar: L10n.Tab.calendar
        case .habits: L10n.Tab.habits
        case .profile: L10n.Tab.profile
        }
    }

    var symbolName: String {
        switch self {
        case .tasks: "checklist"
        case .calendar: "calendar"
        case .habits: "checkmark.circle"
        case .profile: "person.crop.circle"
        }
    }
}

/// Переходы между экранами по действию на другом экране (например, «Добавить первую привычку»).
@MainActor
@Observable
final class AppNavigator {
    var selectedTab: AppTab = .tasks
    /// Экран привычек откроет редактор новой привычки и сбросит флаг.
    var wantsNewHabit = false
    /// Календарь откроет создание задачи и сбросит флаг.
    var wantsNewTask = false

    func openNewHabit() {
        selectedTab = .habits
        wantsNewHabit = true
    }

    func openNewTask() {
        selectedTab = .calendar
        wantsNewTask = true
    }

    /// Профиль откроет историю фокуса и сбросит флаг.
    var wantsFocusHistory = false

    func openFocusHistory() {
        selectedTab = .profile
        wantsFocusHistory = true
    }

    /// Настройки живут во вкладке «Профиль».
    func openSettings() {
        selectedTab = .profile
    }
}
