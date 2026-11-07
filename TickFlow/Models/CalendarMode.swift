import Foundation

/// Способ просмотра календаря.
enum CalendarMode: String, CaseIterable, Identifiable, Codable {
    case month
    case day
    case threeDay
    case week

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: L10n.Calendar.month
        case .day: L10n.Calendar.day
        case .threeDay: L10n.Calendar.threeDays
        case .week: L10n.Calendar.week
        }
    }

    var symbolName: String {
        switch self {
        case .month: "calendar"
        case .day: "rectangle"
        case .threeDay: "rectangle.split.3x1"
        case .week: "calendar.day.timeline.left"
        }
    }

    /// Сколько дней показывает таймлайн. Для месяца — шаг не в днях.
    var dayCount: Int {
        switch self {
        case .month, .day: 1
        case .threeDay: 3
        case .week: 7
        }
    }
}
