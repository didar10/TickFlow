import Foundation
import Observation

@MainActor
@Observable
final class ListEditorViewModel {
    var name = ""
    var colorHex = AppPalette.listColors[0]
    var symbolName = AppPalette.listSymbols[0]

    private let list: TaskList?

    @ObservationIgnored private let listRepository: any TaskListRepository

    init(list: TaskList?, lists: any TaskListRepository) {
        self.list = list
        listRepository = lists
        if let list {
            name = list.name
            colorHex = list.colorHex
            symbolName = list.symbolName
        }
    }

    var navigationTitle: String {
        list == nil ? "Новый список" : "Список"
    }

    var canSave: Bool {
        !trimmedName.isEmpty
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func save() {
        guard canSave else { return }
        listRepository.save(
            TaskListDraft(name: trimmedName, colorHex: colorHex, symbolName: symbolName),
            to: list
        )
    }
}
