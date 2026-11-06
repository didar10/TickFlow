import Foundation
import Observation

struct TaskGroup: Identifiable {
    let id: String
    let title: String
    let tasks: [TaskItem]
}

/// Задачи одной подборки. Фильтрация делается в памяти:
/// для MVP это проще и надёжнее динамических предикатов.
@MainActor
@Observable
final class TaskListViewModel {
    let filter: TaskFilter
    var editingTask: TaskItem?
    var isCreatingTask = false
    var showsCompleted = false

    @ObservationIgnored private let taskRepository: any TaskRepository
    @ObservationIgnored private let listRepository: any TaskListRepository

    init(filter: TaskFilter, tasks: any TaskRepository, lists: any TaskListRepository) {
        self.filter = filter
        taskRepository = tasks
        listRepository = lists
    }

    // MARK: - Данные

    var currentList: TaskList? {
        guard case .list(let id) = filter else { return nil }
        return listRepository.lists.first { $0.id == id }
    }

    var title: String {
        currentList?.name ?? filter.defaultTitle
    }

    var showsListName: Bool {
        filter.isSmart
    }

    var canAddTask: Bool {
        filter != .completed
    }

    var isEmpty: Bool {
        groups.isEmpty && completedTasks.isEmpty
    }

    var completedTasks: [TaskItem] {
        let tasks = taskRepository.tasks
        switch filter {
        case .completed:
            return []
        case .list(let id):
            return tasks.filter { $0.isCompleted && $0.list?.id == id }
        case .today, .upcoming, .all:
            return tasks.filter { task in
                guard task.isCompleted, let completedAt = task.completedAt else { return false }
                return Calendar.current.isDateInToday(completedAt)
            }
        }
    }

    var groups: [TaskGroup] {
        let calendar = Calendar.current
        let active = taskRepository.tasks.filter { filter.matches($0) }

        switch filter {
        case .today, .upcoming:
            let today = calendar.startOfDay(for: .now)
            var overdue: [TaskItem] = []
            var byDay: [Date: [TaskItem]] = [:]

            for task in active {
                guard let due = task.dueDate else { continue }
                let day = calendar.startOfDay(for: due)
                if day < today {
                    overdue.append(task)
                } else {
                    byDay[day, default: []].append(task)
                }
            }

            var result: [TaskGroup] = []
            if !overdue.isEmpty {
                result.append(TaskGroup(id: "overdue", title: "Просрочено", tasks: overdue))
            }
            for day in byDay.keys.sorted() {
                result.append(
                    TaskGroup(
                        id: "day-\(day.timeIntervalSince1970)",
                        title: DateFormatting.dueLabel(for: day, hasTime: false),
                        tasks: byDay[day] ?? []
                    )
                )
            }
            return result

        default:
            guard !active.isEmpty else { return [] }
            return [TaskGroup(id: "main", title: "", tasks: active)]
        }
    }

    // MARK: - Действия

    func toggle(_ task: TaskItem) {
        taskRepository.setCompleted(task, !task.isCompleted)
    }

    func delete(_ task: TaskItem) {
        taskRepository.delete(task)
    }

    func moveToToday(_ task: TaskItem) {
        taskRepository.moveToToday(task)
    }
}
