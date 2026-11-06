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
        case .none: "Без приоритета"
        case .low: "Низкий"
        case .medium: "Средний"
        case .high: "Высокий"
        }
    }

    /// Подпись в меню редактора.
    var menuTitle: String {
        switch self {
        case .none: "Без приоритета"
        case .low: "Низкий приоритет"
        case .medium: "Средний приоритет"
        case .high: "Высокий приоритет"
        }
    }

    /// Цвета флажка из макета.
    var color: Color {
        switch self {
        case .none: Color(hex: "#AEAEB2")
        case .low: Color(hex: "#5B5BD6")
        case .medium: Color(hex: "#CF8526")
        case .high: Color(hex: "#D93D42")
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
