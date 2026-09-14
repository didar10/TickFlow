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

    var color: Color {
        switch self {
        case .none: .secondary
        case .low: .blue
        case .medium: .orange
        case .high: .red
        }
    }

    var symbolName: String {
        self == .none ? "flag" : "flag.fill"
    }
}
