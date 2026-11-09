import Foundation
import Observation

/// Что открыть в редакторе категории.
struct ListEditorRequest: Identifiable {
    let id = UUID()
    let list: TaskList?
}

/// Экран «Категории»: список, учёт времени по умолчанию и создание новой.
@MainActor
@Observable
final class CategoriesViewModel {
    struct Row: Identifiable {
        let id: UUID
        let name: String
        let colorHex: String
        let openTasks: String
        let tracksTime: Bool
    }

    var editorRequest: ListEditorRequest?

    @ObservationIgnored private let lists: any TaskListRepository

    init(lists: any TaskListRepository) {
        self.lists = lists
    }

    var rows: [Row] {
        lists.lists.map { list in
            Row(
                id: list.id,
                name: list.name,
                colorHex: list.colorHex,
                openTasks: L10n.Lists.openTasks(list.activeCount),
                tracksTime: list.tracksTimeByDefault
            )
        }
    }

    func edit(_ id: UUID) {
        guard let list = lists.lists.first(where: { $0.id == id }) else { return }
        editorRequest = ListEditorRequest(list: list)
    }

    func add() {
        editorRequest = ListEditorRequest(list: nil)
    }
}
