import Foundation
import Observation

/// Лист «Фильтр»: категории и статус. Меняет общий `TaskFilterStore`.
@MainActor
@Observable
final class FilterSheetViewModel {
    struct CategoryOption: Identifiable {
        let id: UUID
        let name: String
        let colorHex: String
        let isSelected: Bool
    }

    @ObservationIgnored private let filter: TaskFilterStore
    @ObservationIgnored private let lists: any TaskListRepository

    init(filter: TaskFilterStore, lists: any TaskListRepository) {
        self.filter = filter
        self.lists = lists
    }

    var categories: [CategoryOption] {
        lists.lists.map {
            CategoryOption(id: $0.id, name: $0.name, colorHex: $0.colorHex, isSelected: filter.categoryIDs.contains($0.id))
        }
    }

    var statusOptions: [(value: TaskFilterStore.Status, title: String)] {
        TaskFilterStore.Status.allCases.map { ($0, $0.title) }
    }

    var status: TaskFilterStore.Status {
        get { filter.status }
        set { filter.status = newValue }
    }

    func toggleCategory(_ id: UUID) { filter.toggleCategory(id) }
    func reset() { filter.reset() }
}
