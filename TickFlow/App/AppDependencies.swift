import Foundation
import Observation
import SwiftData

/// Собирает зависимости и создаёт view model экранов.
@MainActor
@Observable
final class AppDependencies {
    /// ModelContext не удерживает контейнер: без этой ссылки база освободится и вставка упадёт.
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let repository: SwiftDataRepository

    init(container: ModelContainer) {
        self.container = container
        repository = SwiftDataRepository(context: container.mainContext)
    }

    /// Хранилище в памяти для превью.
    static func preview() -> AppDependencies {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(
                for: TaskList.self, TaskItem.self, Subtask.self,
                configurations: configuration
            )
            let dependencies = AppDependencies(container: container)
            SeedService.seedIfNeeded(tasks: dependencies.repository, lists: dependencies.repository)
            return dependencies
        } catch {
            fatalError("Не удалось создать ModelContainer: \(error)")
        }
    }

    func bootstrap() async {
        SeedService.seedIfNeeded(tasks: repository, lists: repository)
        await NotificationScheduler.requestAuthorization()
    }

    // MARK: - View model

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(tasks: repository, lists: repository)
    }

    func makeTaskListViewModel(filter: TaskFilter) -> TaskListViewModel {
        TaskListViewModel(filter: filter, tasks: repository, lists: repository)
    }

    func makeCalendarViewModel() -> CalendarViewModel {
        CalendarViewModel(tasks: repository, lists: repository)
    }

    func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(tasks: repository)
    }

    func makeTaskEditorViewModel(
        task: TaskItem?,
        defaultList: TaskList? = nil,
        defaultDueDate: Date? = nil,
        defaultHasTime: Bool = false
    ) -> TaskEditorViewModel {
        TaskEditorViewModel(
            task: task,
            defaultList: defaultList,
            defaultDueDate: defaultDueDate,
            defaultHasTime: defaultHasTime,
            tasks: repository,
            lists: repository
        )
    }

    func makeListEditorViewModel(list: TaskList?) -> ListEditorViewModel {
        ListEditorViewModel(list: list, lists: repository)
    }
}
