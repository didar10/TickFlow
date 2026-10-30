import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    let smartFilters: [TaskFilter] = [.today, .upcoming, .all, .completed]
    var isCreatingList = false
    var listBeingEdited: TaskList?

    @ObservationIgnored private let taskRepository: any TaskRepository
    @ObservationIgnored private let listRepository: any TaskListRepository

    init(tasks: any TaskRepository, lists: any TaskListRepository) {
        taskRepository = tasks
        listRepository = lists
    }

    var lists: [TaskList] {
        listRepository.lists
    }

    func count(for filter: TaskFilter) -> Int {
        guard filter != .completed else { return 0 }
        return taskRepository.tasks.filter { filter.matches($0) }.count
    }

    func delete(_ list: TaskList) {
        listRepository.delete(list)
    }
}
