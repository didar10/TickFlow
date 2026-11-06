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
    @ObservationIgnored private let habitRepository: SwiftDataHabitRepository
    @ObservationIgnored let settingsRepository: UserDefaultsSettingsRepository
    @ObservationIgnored let toasts = ToastCenter()
    /// Фильтр категорий и статуса, общий для календаря и задач.
    @ObservationIgnored let taskFilter = TaskFilterStore()
    @ObservationIgnored let navigator = AppNavigator()

    static let modelTypes: [any PersistentModel.Type] = [
        TaskList.self, TaskItem.self, Subtask.self, Habit.self, HabitLog.self
    ]

    init(container: ModelContainer, defaults: UserDefaults = .standard) {
        self.container = container
        repository = SwiftDataRepository(context: container.mainContext)
        habitRepository = SwiftDataHabitRepository(context: container.mainContext)
        settingsRepository = UserDefaultsSettingsRepository(defaults: defaults)
        repository.remindersEnabled = settingsRepository.settings.taskRemindersEnabled
        habitRepository.remindersEnabled = settingsRepository.settings.habitRemindersEnabled
    }

    /// Хранилище в памяти для превью.
    static func preview() -> AppDependencies {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(
                for: Schema(modelTypes),
                configurations: configuration
            )
            let dependencies = AppDependencies(
                container: container,
                defaults: UserDefaults(suiteName: "preview") ?? .standard
            )
            dependencies.seed()
            return dependencies
        } catch {
            fatalError("Не удалось создать ModelContainer: \(error)")
        }
    }

    /// Запуск: перепланирует напоминания, если уведомления уже разрешены.
    /// Разрешение запрашивается в онбординге, а пример данных — по кнопке.
    func bootstrap() async {
        guard settingsRepository.settings.hasCompletedOnboarding, await NotificationScheduler.isAuthorized() else { return }
        repository.rescheduleReminders(enabled: settingsRepository.settings.taskRemindersEnabled)
        habitRepository.rescheduleReminders(enabled: settingsRepository.settings.habitRemindersEnabled)
    }

    private func seed() {
        SeedService.seedIfNeeded(tasks: repository, lists: repository, habits: habitRepository)
    }

    /// «Загрузить пример»: категории, задачи и привычки с историей.
    func loadSampleData() {
        SeedService.seedSample(tasks: repository, lists: repository, habits: habitRepository)
    }

    // MARK: - View model

    func makeRootViewModel() -> RootViewModel {
        RootViewModel(settings: settingsRepository, toasts: toasts, navigator: navigator)
    }

    func makeTasksViewModel() -> TasksViewModel {
        TasksViewModel(
            tasks: repository,
            lists: repository,
            settings: settingsRepository,
            filter: taskFilter,
            toasts: toasts,
            navigator: navigator
        )
    }

    func makeFilterSheetViewModel() -> FilterSheetViewModel {
        FilterSheetViewModel(filter: taskFilter, lists: repository)
    }

    func makeCalendarViewModel() -> CalendarViewModel {
        CalendarViewModel(
            tasks: repository,
            lists: repository,
            settings: settingsRepository,
            filter: taskFilter,
            toasts: toasts,
            navigator: navigator,
            loadSampleData: { [weak self] in self?.loadSampleData() }
        )
    }

    func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(tasks: repository, settings: settingsRepository, toasts: toasts)
    }

    func makeTaskEditorViewModel(request: TaskEditorRequest) -> TaskEditorViewModel {
        TaskEditorViewModel(
            request: request,
            settings: settingsRepository.settings,
            tasks: repository,
            lists: repository,
            toasts: toasts
        )
    }

    func makeHabitsViewModel() -> HabitsViewModel {
        HabitsViewModel(habits: habitRepository, settings: settingsRepository, toasts: toasts, navigator: navigator)
    }

    func makeHabitDetailViewModel(id: UUID) -> HabitDetailViewModel {
        HabitDetailViewModel(id: id, habits: habitRepository, settings: settingsRepository, toasts: toasts)
    }

    func makeHabitEditorViewModel(request: HabitEditorRequest) -> HabitEditorViewModel {
        HabitEditorViewModel(
            request: request,
            habits: habitRepository,
            settings: settingsRepository,
            toasts: toasts,
            navigator: navigator
        )
    }

    func makeInsightsViewModel() -> InsightsViewModel {
        InsightsViewModel(tasks: repository, habits: habitRepository, settings: settingsRepository, navigator: navigator)
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            settings: settingsRepository,
            tasks: repository,
            lists: repository,
            habits: habitRepository,
            toasts: toasts,
            navigator: navigator,
            loadSampleData: { [weak self] in self?.loadSampleData() }
        )
    }

    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(
            settings: settingsRepository,
            habits: habitRepository,
            tasks: repository,
            navigator: navigator,
            loadSampleData: { [weak self] in self?.loadSampleData() }
        )
    }

    func makeListEditorViewModel(list: TaskList?) -> ListEditorViewModel {
        ListEditorViewModel(list: list, lists: repository, toasts: toasts)
    }
}
