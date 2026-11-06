import Foundation
import Observation

/// Вкладки приложения в порядке таб-бара.
enum AppTab: Hashable, CaseIterable {
    case calendar, tasks, habits, insights

    var title: String {
        switch self {
        case .calendar: "Календарь"
        case .tasks: "Задачи"
        case .habits: "Привычки"
        case .insights: "Аналитика"
        }
    }

    var symbolName: String {
        switch self {
        case .calendar: "calendar"
        case .tasks: "checklist"
        case .habits: "checkmark.circle"
        case .insights: "chart.bar"
        }
    }
}

/// Переходы между экранами по действию на другом экране (например, «Добавить первую привычку»).
@MainActor
@Observable
final class AppNavigator {
    var selectedTab: AppTab = .calendar
    /// Экран привычек откроет редактор новой привычки и сбросит флаг.
    var wantsNewHabit = false
    /// Календарь откроет создание задачи и сбросит флаг.
    var wantsNewTask = false
    var isSettingsPresented = false

    func openNewHabit() {
        selectedTab = .habits
        wantsNewHabit = true
    }

    func openNewTask() {
        selectedTab = .calendar
        wantsNewTask = true
    }

    func openSettings() {
        isSettingsPresented = true
    }
}
