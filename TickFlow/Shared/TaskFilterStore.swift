import Foundation
import Observation

/// Фильтр по категориям и статусу. Общий для календаря и экрана задач, как в макете.
@MainActor
@Observable
final class TaskFilterStore {
    enum Status: Hashable, CaseIterable {
        case all, open, completed

        var title: String {
            switch self {
            case .all: L10n.Common.all
            case .open: L10n.Filter.open
            case .completed: L10n.Filter.completed
            }
        }
    }

    var categoryIDs: Set<UUID> = []
    var status: Status = .all

    var isActive: Bool { !categoryIDs.isEmpty || status != .all }

    func matches(_ task: TaskItem) -> Bool {
        if !categoryIDs.isEmpty {
            guard let id = task.list?.id, categoryIDs.contains(id) else { return false }
        }
        switch status {
        case .all: return true
        case .open: return !task.isCompleted
        case .completed: return task.isCompleted
        }
    }

    func toggleCategory(_ id: UUID) {
        if categoryIDs.contains(id) { categoryIDs.remove(id) } else { categoryIDs.insert(id) }
    }

    func reset() {
        categoryIDs = []
        status = .all
    }
}
