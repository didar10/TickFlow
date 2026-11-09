import Foundation
import Observation

/// Экран «Задачи»: поиск, фильтр по категориям, сортировка, плотность и группы по сроку.
@MainActor
@Observable
final class TasksViewModel {
    enum Sort { case date, priority }
    enum Density { case comfortable, compact }

    enum GroupKind: String, CaseIterable {
        case overdue, today, upcoming, undated, completed

        var title: String {
            switch self {
            case .overdue: L10n.Common.overdue
            case .today: L10n.Common.today
            case .upcoming: L10n.Tasks.upcoming
            case .undated: L10n.Common.noDate
            case .completed: L10n.Common.completed
            }
        }
    }

    struct Group: Identifiable {
        var id: GroupKind { kind }
        let kind: GroupKind
        let title: String
        let count: Int
        let isDanger: Bool
        let isCollapsible: Bool
        let toggleTitle: String
        let rows: [TaskRowItem]
    }

    struct CategoryChip: Identifiable {
        /// `nil` — чип «Все».
        let id: UUID?
        let title: String
        let colorHex: String?
        let isSelected: Bool
    }

    var query = ""
    private(set) var sort: Sort = .date
    private(set) var density: Density = .comfortable
    private(set) var showsCompleted = true
    var editorRequest: TaskEditorRequest?

    @ObservationIgnored private let taskRepository: any TaskRepository
    @ObservationIgnored private let listRepository: any TaskListRepository
    @ObservationIgnored private let settings: any SettingsRepository
    @ObservationIgnored private let filter: TaskFilterStore
    @ObservationIgnored private let actions: TaskActions
    @ObservationIgnored private let navigator: AppNavigator
    @ObservationIgnored private let clock: any AppClock
    @ObservationIgnored private let focus: FocusEngine?

    init(
        tasks: any TaskRepository,
        lists: any TaskListRepository,
        settings: any SettingsRepository,
        filter: TaskFilterStore,
        toasts: ToastCenter,
        navigator: AppNavigator,
        focus: FocusEngine? = nil,
        clock: any AppClock = SystemClock()
    ) {
        self.clock = clock
        self.focus = focus
        self.navigator = navigator
        taskRepository = tasks
        listRepository = lists
        self.settings = settings
        self.filter = filter
        actions = TaskActions(tasks: tasks, toasts: toasts)
    }

    private var format: DisplayFormatter { DisplayFormatter(settings: settings.settings, clock: clock) }

    // MARK: - Шапка

    var hasQuery: Bool { !trimmedQuery.isEmpty }
    var trimmedQueryText: String { trimmedQuery }
    var sortTitle: String { sort == .date ? L10n.Common.date : L10n.Common.priority }
    var densityToggleTitle: String { density == .compact ? L10n.Tasks.comfortableView : L10n.Tasks.compactView }
    var isCompact: Bool { density == .compact }

    var categoryChips: [CategoryChip] {
        let all = CategoryChip(id: nil, title: L10n.Common.all, colorHex: nil, isSelected: filter.categoryIDs.isEmpty)
        return [all] + listRepository.lists.map {
            CategoryChip(id: $0.id, title: $0.name, colorHex: $0.colorHex, isSelected: filter.categoryIDs.contains($0.id))
        }
    }

    func selectCategory(_ id: UUID?) {
        if let id { filter.toggleCategory(id) } else { filter.categoryIDs = [] }
    }


    func toggleSort() { sort = sort == .date ? .priority : .date }
    func toggleDensity() { density = density == .compact ? .comfortable : .compact }
    func clearQuery() { query = "" }

    // MARK: - Сводка дня

    var hasAnyTasks: Bool { !taskRepository.tasks.isEmpty }

    private var todayTasks: [TaskItem] {
        let format = format
        return taskRepository.tasks.filter { $0.occurs(on: format.today, calendar: format.calendar) }
    }

    var todaySummary: String {
        let tasks = todayTasks
        return L10n.Common.doneOfTotal(tasks.filter(\.isCompleted).count, tasks.count)
    }

    var todayProgress: Double {
        let tasks = todayTasks
        guard !tasks.isEmpty else { return 0 }
        return Double(tasks.filter(\.isCompleted).count) / Double(tasks.count)
    }

    // MARK: - Группы

    var groups: [Group] {
        let format = format
        let all = taskRepository.tasks
        let visible = all.filter { filter.matches($0) && matchesQuery($0) }

        return GroupKind.allCases.compactMap { kind in
            let tasks = visible.filter { self.kind(of: $0, format: format) == kind }.sorted(by: order)
            guard !tasks.isEmpty else { return nil }
            let collapsed = kind == .completed && !showsCompleted
            return Group(
                kind: kind,
                title: kind.title,
                count: tasks.count,
                isDanger: kind == .overdue,
                isCollapsible: kind == .completed,
                toggleTitle: showsCompleted ? L10n.Common.hide : L10n.Common.show,
                rows: collapsed ? [] : tasks.map { TaskRowItem(task: $0, format: format, allTasks: all) }
            )
        }
    }

    var showsNoResults: Bool { hasQuery && hasAnyTasks && groups.isEmpty }
    var showsNoTasks: Bool { !hasAnyTasks }

    func toggleCompletedGroup() { showsCompleted.toggle() }

    // MARK: - Действия

    func toggle(_ id: UUID) {
        guard let task = task(id) else { return }
        actions.toggleCompleted(task)
    }

    func open(_ id: UUID) {
        guard let task = task(id) else { return }
        editorRequest = .edit(task)
    }

    // MARK: - Учёт времени

    var canTrackTime: Bool { focus != nil }

    /// Кнопка таймера в строке: во время сессии задачи открывает экран, иначе запускает таймер.
    func timerTapped(_ id: UUID) {
        guard let focus, let task = task(id) else { return }
        if focus.isLive(task) {
            focus.present()
        } else {
            focus.startTimer(task: task)
        }
    }

    /// «Фокус» в шапке: фокус без задачи.
    func openFocus() {
        focus?.openFocus()
    }

    /// «+» на экране задач: задача на сегодня без времени, как в макете.
    func startCreating() {
        editorRequest = .new(day: format.today)
    }

    // MARK: - Внутреннее

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func matchesQuery(_ task: TaskItem) -> Bool {
        trimmedQuery.isEmpty || task.title.localizedStandardContains(trimmedQuery)
    }

    private func task(_ id: UUID) -> TaskItem? {
        taskRepository.tasks.first { $0.id == id }
    }

    private func kind(of task: TaskItem, format: DisplayFormatter) -> GroupKind {
        if task.isCompleted { return .completed }
        guard let due = task.dueDate, let last = task.lastDay else { return .undated }
        let today = format.today
        if last < today { return .overdue }
        if format.calendar.startOfDay(for: due) <= today { return .today }
        return .upcoming
    }

    /// По дате: сначала ранние, задачи без времени выше задач со временем того же дня.
    /// По приоритету: сначала высокий, внутри — по дате.
    private func order(_ a: TaskItem, _ b: TaskItem) -> Bool {
        if sort == .priority, a.priority != b.priority {
            return a.priority.rawValue > b.priority.rawValue
        }
        let calendar = format.calendar
        let dayA = a.dueDate.map { calendar.startOfDay(for: $0) } ?? .distantFuture
        let dayB = b.dueDate.map { calendar.startOfDay(for: $0) } ?? .distantFuture
        if dayA != dayB { return dayA < dayB }
        if a.hasTime != b.hasTime { return !a.hasTime }
        return (a.dueDate ?? .distantFuture, a.sortOrder) < (b.dueDate ?? .distantFuture, b.sortOrder)
    }
}
