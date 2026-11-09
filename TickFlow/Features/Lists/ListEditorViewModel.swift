import Foundation
import Observation

/// Создание, изменение и удаление категории.
@MainActor
@Observable
final class ListEditorViewModel {
    var name = ""
    private(set) var colorHex = AppPalette.listColors[0]
    private(set) var symbolName = AppPalette.listSymbols[0]
    var tracksTimeByDefault = false
    var isDeleteConfirmationPresented = false
    private(set) var isFinished = false

    @ObservationIgnored private let list: TaskList?
    @ObservationIgnored private let listRepository: any TaskListRepository
    @ObservationIgnored private let toasts: ToastCenter

    init(list: TaskList?, lists: any TaskListRepository, toasts: ToastCenter) {
        self.list = list
        listRepository = lists
        self.toasts = toasts
        if let list {
            name = list.name
            colorHex = list.colorHex
            symbolName = list.symbolName
            tracksTimeByDefault = list.tracksTimeByDefault
        } else {
            // Новой категории — первый цвет, которого ещё нет.
            let used = Set(lists.lists.map { $0.colorHex.uppercased() })
            colorHex = AppPalette.listColors.first { !used.contains($0) } ?? AppPalette.listColors[0]
        }
    }

    var title: String { list == nil ? L10n.Lists.newCategory : L10n.Common.category }
    var saveTitle: String { list == nil ? L10n.Common.add : L10n.Common.save }
    var canSave: Bool { !trimmedName.isEmpty }
    var canDelete: Bool { list != nil }

    var colors: [String] { AppPalette.listColors }
    var symbols: [String] { AppPalette.listSymbols }

    func selectColor(_ hex: String) { colorHex = hex }
    func selectSymbol(_ symbol: String) { symbolName = symbol }

    var deleteMessage: String {
        let count = list?.tasks.count ?? 0
        return count == 0
            ? L10n.Lists.noTasks
            : L10n.Lists.deleteWarning(L10n.Plural.tasks(count))
    }

    func save() {
        guard canSave else { return }
        listRepository.save(
            TaskListDraft(
                name: trimmedName, colorHex: colorHex, symbolName: symbolName,
                tracksTimeByDefault: tracksTimeByDefault
            ),
            to: list
        )
        isFinished = true
    }

    func requestDelete() {
        isDeleteConfirmationPresented = true
    }

    func confirmDelete() {
        guard let list else { return }
        let name = list.name
        listRepository.delete(list)
        toasts.show(L10n.Lists.deletedToast(name))
        isFinished = true
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
