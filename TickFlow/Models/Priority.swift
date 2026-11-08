import SwiftUI

/// Приоритет задачи. В SwiftData хранится как Int (`TaskItem.priorityRaw`),
/// чтобы предикаты и сортировки работали без ограничений.
enum Priority: Int, CaseIterable, Identifiable, Codable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: L10n.Priority.none
        case .low: L10n.Priority.low
        case .medium: L10n.Priority.medium
        case .high: L10n.Priority.high
        }
    }

    /// Подпись в меню редактора.
    var menuTitle: String {
        switch self {
        case .none: L10n.Priority.none
        case .low: L10n.Priority.lowFull
        case .medium: L10n.Priority.mediumFull
        case .high: L10n.Priority.highFull
        }
    }

    /// Цвета флажка из макета.
    var color: Color {
        switch self {
        case .none: AppColors.textQuaternary
        case .low: AppColors.accent
        case .medium: Color(hex: "#CF8526")
        case .high: AppColors.danger
        }
    }

    /// "!", "!!", "!!!" перед названием задачи в списке.
    var marks: String {
        String(repeating: "!", count: rawValue)
    }

    var symbolName: String {
        self == .none ? "flag" : "flag.fill"
    }
}
