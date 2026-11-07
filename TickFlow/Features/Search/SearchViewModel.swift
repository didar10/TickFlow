import Foundation
import Observation

/// Полноэкранный поиск по названию, заметкам и категории.
@MainActor
@Observable
final class SearchViewModel {
    struct ResultRow: Identifiable {
        let id: UUID
        let title: String
        let meta: String
        let colorHex: String
        let isCompleted: Bool
        let isOverdue: Bool
    }

    var query = ""
    /// Открытый редактор задачи.
    var editorRequest: TaskEditorRequest?

    let suggestions = [L10n.Sample.work, L10n.Search.suggestionReview, L10n.Sample.health, L10n.Sample.errands]

    @ObservationIgnored private let taskRepository: any TaskRepository
    @ObservationIgnored private let settings: any SettingsRepository
    @ObservationIgnored private let actions: TaskActions

    init(tasks: any TaskRepository, settings: any SettingsRepository, toasts: ToastCenter) {
        taskRepository = tasks
        self.settings = settings
        actions = TaskActions(tasks: tasks, toasts: toasts)
    }

    var hasQuery: Bool { !trimmedQuery.isEmpty }
    var showsNoResults: Bool { hasQuery && results.isEmpty }
    var trimmedQueryText: String { trimmedQuery }

    /// Сначала незавершённые, внутри групп — по сроку.
    var results: [ResultRow] {
        guard hasQuery else { return [] }
        let format = DisplayFormatter(settings: settings.settings)
        let matches = taskRepository.tasks
            .filter { task in
                task.title.localizedStandardContains(trimmedQuery)
                    || task.notes.localizedStandardContains(trimmedQuery)
                    || (task.list?.name.localizedStandardContains(trimmedQuery) ?? false)
            }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        return (matches.filter { !$0.isCompleted } + matches.filter(\.isCompleted)).map { task in
            ResultRow(
                id: task.id,
                title: task.title,
                meta: format.dueLabel(for: task) + " · " + (task.list?.name ?? L10n.Common.noCategory),
                colorHex: task.list?.colorHex ?? AppColors.fallbackList,
                isCompleted: task.isCompleted,
                isOverdue: task.isOverdue
            )
        }
    }

    func applySuggestion(_ text: String) {
        query = text
    }

    func open(_ id: UUID) {
        guard let task = taskRepository.tasks.first(where: { $0.id == id }) else { return }
        editorRequest = .edit(task)
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
