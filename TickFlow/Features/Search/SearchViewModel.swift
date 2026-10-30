import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    var query = ""
    var editingTask: TaskItem?

    @ObservationIgnored private let taskRepository: any TaskRepository

    init(tasks: any TaskRepository) {
        taskRepository = tasks
    }

    var hasQuery: Bool {
        !query.isEmpty
    }

    /// Сначала незавершённые, внутри групп — новые выше.
    var results: [TaskItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let matches = taskRepository.tasks
            .filter { task in
                task.title.localizedStandardContains(trimmed)
                    || task.notes.localizedStandardContains(trimmed)
                    || (task.list?.name.localizedStandardContains(trimmed) ?? false)
            }
            .sorted { $0.createdAt > $1.createdAt }
        return matches.filter { !$0.isCompleted } + matches.filter(\.isCompleted)
    }

    func toggle(_ task: TaskItem) {
        taskRepository.setCompleted(task, !task.isCompleted)
    }
}
