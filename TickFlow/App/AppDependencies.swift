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
    @ObservationIgnored private let timeEntryRepository: SwiftDataTimeEntryRepository
    @ObservationIgnored let settingsRepository: UserDefaultsSettingsRepository
    @ObservationIgnored let toasts = ToastCenter()
    /// Фильтр категорий и статуса, общий для календаря и задач.
    @ObservationIgnored let taskFilter = TaskFilterStore()
    @ObservationIgnored let navigator = AppNavigator()
    /// Панель быстрого создания задачи поверх всего приложения (над таб-баром).
    @ObservationIgnored let quickEditorHost = QuickEditorHost()
    /// Сессии фокуса и таймер задач: одно состояние на всё приложение.
    @ObservationIgnored let focus: FocusEngine
    @ObservationIgnored private let clock: any AppClock
    @ObservationIgnored private let reminders: any ReminderScheduling

    static let modelTypes: [any PersistentModel.Type] = [
        TaskList.self, TaskItem.self, Subtask.self, Habit.self, HabitLog.self, TimeEntry.self
    ]

    init(
        container: ModelContainer,
        defaults: UserDefaults = .standard,
        clock: any AppClock = SystemClock(),
        reminders: any ReminderScheduling = SystemReminderScheduler()
    ) {
        self.container = container
        self.clock = clock
        self.reminders = reminders
        repository = SwiftDataRepository(context: container.mainContext, clock: clock, reminders: reminders)
        habitRepository = SwiftDataHabitRepository(context: container.mainContext, clock: clock, reminders: reminders)
        timeEntryRepository = SwiftDataTimeEntryRepository(context: container.mainContext)
        settingsRepository = UserDefaultsSettingsRepository(defaults: defaults)
        repository.remindersEnabled = settingsRepository.settings.taskRemindersEnabled
        focus = FocusEngine(
            entries: timeEntryRepository,
            tasks: repository,
            settings: settingsRepository,
            clock: clock,
            defaults: defaults,
            autoTick: !LaunchEnvironment.isRunningUnitTests
        )
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
        guard settingsRepository.settings.hasCompletedOnboarding, await reminders.isAuthorized() else { return }
        repository.rescheduleReminders(enabled: settingsRepository.settings.taskRemindersEnabled)
        habitRepository.rescheduleReminders(enabled: settingsRepository.settings.habitRemindersEnabled)
    }

    private func seed() {
        SeedService.seedIfNeeded(tasks: repository, lists: repository, habits: habitRepository, timeEntries: timeEntryRepository)
    }

    /// «Загрузить пример»: категории, задачи и привычки с историей.
    func loadSampleData() {
        SeedService.seedSample(tasks: repository, lists: repository, habits: habitRepository, timeEntries: timeEntryRepository)
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
            navigator: navigator,
            focus: focus,
            clock: clock
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
            loadSampleData: { [weak self] in self?.loadSampleData() },
            timeEntries: timeEntryRepository,
            focus: focus,
            makeSessionDetail: { [unowned self] in makeSessionDetail(entry: $0, onOpenTask: $1) },
            clock: clock
        )
    }

    func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(tasks: repository, settings: settingsRepository, toasts: toasts, clock: clock)
    }

    func makeTaskEditorViewModel(request: TaskEditorRequest) -> TaskEditorViewModel {
        TaskEditorViewModel(
            request: request,
            settings: settingsRepository.settings,
            tasks: repository,
            lists: repository,
            toasts: toasts,
            focus: focus,
            timeEntries: timeEntryRepository,
            stopFlow: makeStopFlow(),
            makeEntryEditor: entryEditorFactory,
            makeSessionDetail: { [unowned self] in makeSessionDetail(entry: $0) },
            clock: clock
        )
    }

    func makeHabitsViewModel() -> HabitsViewModel {
        HabitsViewModel(habits: habitRepository, settings: settingsRepository, toasts: toasts, navigator: navigator, clock: clock)
    }

    func makeHabitDetailViewModel(id: UUID) -> HabitDetailViewModel {
        HabitDetailViewModel(id: id, habits: habitRepository, settings: settingsRepository, toasts: toasts, clock: clock)
    }

    func makeHabitEditorViewModel(request: HabitEditorRequest) -> HabitEditorViewModel {
        HabitEditorViewModel(
            request: request,
            habits: habitRepository,
            settings: settingsRepository,
            toasts: toasts,
            navigator: navigator,
            clock: clock
        )
    }

    func makeInsightsViewModel() -> InsightsViewModel {
        InsightsViewModel(
            tasks: repository,
            habits: habitRepository,
            settings: settingsRepository,
            navigator: navigator,
            timeEntries: timeEntryRepository,
            clock: clock
        )
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            settings: settingsRepository,
            tasks: repository,
            lists: repository,
            habits: habitRepository,
            timeEntries: timeEntryRepository,
            toasts: toasts,
            navigator: navigator,
            loadSampleData: { [weak self] in self?.loadSampleData() },
            clock: clock,
            reminders: reminders
        )
    }

    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(
            settings: settingsRepository,
            habits: habitRepository,
            tasks: repository,
            navigator: navigator,
            loadSampleData: { [weak self] in self?.loadSampleData() },
            clock: clock,
            reminders: reminders
        )
    }

    func makeListEditorViewModel(list: TaskList?, onSaved: ((TaskList) -> Void)? = nil) -> ListEditorViewModel {
        ListEditorViewModel(list: list, lists: repository, toasts: toasts, onSaved: onSaved)
    }

    func makeCategoriesViewModel() -> CategoriesViewModel {
        CategoriesViewModel(lists: repository)
    }

    // MARK: - Фокус

    private var displayFormatter: DisplayFormatter { DisplayFormatter(settings: settingsRepository.settings, clock: clock) }

    func makeTimeEntryEditor(mode: TimeEntryEditorViewModel.Mode, task: TaskItem?, start: Date, end: Date) -> TimeEntryEditorViewModel {
        TimeEntryEditorViewModel(
            mode: mode, task: task, start: start, end: end,
            entries: timeEntryRepository, tasks: repository, focus: focus, toasts: toasts, format: displayFormatter
        )
    }

    private var entryEditorFactory: TimeEntryEditorFactory {
        { [unowned self] mode, task, start, end in makeTimeEntryEditor(mode: mode, task: task, start: start, end: end) }
    }

    func makeStopFlow() -> FocusStopFlow {
        FocusStopFlow(focus: focus, toasts: toasts, makeEntryEditor: entryEditorFactory)
    }

    func makeFocusScreenViewModel(host: FocusEngine.ScreenHost, onOpenHistory: (() -> Void)? = nil) -> FocusScreenViewModel {
        FocusScreenViewModel(
            focus: focus, host: host, entries: timeEntryRepository, tasks: repository,
            format: displayFormatter, stopFlow: makeStopFlow(), onOpenHistory: onOpenHistory
        )
    }

    func makeSessionDetail(entry: TimeEntry, onOpenTask: ((TaskItem) -> Void)? = nil) -> SessionDetailViewModel {
        SessionDetailViewModel(
            entry: entry, entries: timeEntryRepository, toasts: toasts, format: displayFormatter,
            makeEntryEditor: entryEditorFactory, onOpenTask: onOpenTask
        )
    }

    func makeFocusHistoryViewModel() -> FocusHistoryViewModel {
        FocusHistoryViewModel(
            entries: timeEntryRepository,
            settings: settingsRepository,
            makeSessionDetail: { [unowned self] in makeSessionDetail(entry: $0, onOpenTask: $1) },
            clock: clock
        )
    }

    func makeFocusSettingsViewModel() -> FocusSettingsViewModel {
        FocusSettingsViewModel(settings: settingsRepository, focus: focus)
    }
}
