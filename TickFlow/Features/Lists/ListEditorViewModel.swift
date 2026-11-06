import Foundation
import Observation

/// Создание, изменение и удаление категории.
@MainActor
@Observable
final class ListEditorViewModel {
    var name = ""
    private(set) var colorHex = AppPalette.listColors[0]
    private(set) var symbolName = AppPalette.listSymbols[0]
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
        } else {
            // Новой категории — первый цвет, которого ещё нет.
            let used = Set(lists.lists.map { $0.colorHex.uppercased() })
            colorHex = AppPalette.listColors.first { !used.contains($0) } ?? AppPalette.listColors[0]
        }
    }

    var title: String { list == nil ? "Новая категория" : "Категория" }
    var saveTitle: String { list == nil ? "Добавить" : "Сохранить" }
    var canSave: Bool { !trimmedName.isEmpty }
    var canDelete: Bool { list != nil }

    var colors: [String] { AppPalette.listColors }
    var symbols: [String] { AppPalette.listSymbols }

    func selectColor(_ hex: String) { colorHex = hex }
    func selectSymbol(_ symbol: String) { symbolName = symbol }

    var deleteMessage: String {
        let count = list?.tasks.count ?? 0
        return count == 0
            ? "В категории нет задач."
            : "Вместе с категорией удалятся \(count) \(Plural.tasks(count)). Это нельзя отменить."
    }

    func save() {
        guard canSave else { return }
        listRepository.save(
            TaskListDraft(name: trimmedName, colorHex: colorHex, symbolName: symbolName),
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
        toasts.show("Категория «\(name)» удалена")
        isFinished = true
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
