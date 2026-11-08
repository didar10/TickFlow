import Foundation
import Testing
@testable import TickFlow

/// Сегодня — воскресенье 08.11.2026, 09:00.
@MainActor
struct TasksViewModelTests {
    let fixture: ModelFixture
    let clock = FixedClock("2026-11-08 09:00")
    let repository = FakeTaskRepository()
    let settings = FakeSettingsRepository()
    let filter = TaskFilterStore()
    let toasts = ToastCenter(sleep: { _ in try await Task.sleep(for: .seconds(3600)) })
    let navigator = AppNavigator()

    init() throws {
        fixture = try ModelFixture()
    }

    private func screen(_ tasks: [TaskItem] = [], lists: [TaskList] = []) -> TasksViewModel {
        repository.insert(tasks)
        repository.insert(lists)
        return TasksViewModel(
            tasks: repository, lists: repository, settings: settings, filter: filter,
            toasts: toasts, navigator: navigator, clock: clock
        )
    }

    private func titles(_ screen: TasksViewModel, _ kind: TasksViewModel.GroupKind) -> [String] {
        screen.groups.first { $0.kind == kind }?.rows.map(\.title) ?? []
    }

    // MARK: - Группы

    @Test func tasksAreGroupedByDue() {
        let screen = screen([
            fixture.task("Вчера", due: "2026-11-07 10:00"),
            fixture.task("Сегодня", due: "2026-11-08"),
            fixture.task("Многодневная", due: "2026-11-06", endDay: "2026-11-09"),
            fixture.task("Завтра", due: "2026-11-09 10:00"),
            fixture.task("Без даты"),
            fixture.task("Сделано", due: "2026-11-01", completed: true),
        ])
        #expect(screen.groups.map(\.kind) == [.overdue, .today, .upcoming, .undated, .completed])
        #expect(titles(screen, .overdue) == ["Вчера"])
        #expect(Set(titles(screen, .today)) == ["Сегодня", "Многодневная"])
        #expect(titles(screen, .upcoming) == ["Завтра"])
        #expect(titles(screen, .undated) == ["Без даты"])
        #expect(titles(screen, .completed) == ["Сделано"])

        let overdue = screen.groups[0]
        #expect(overdue.title == "Просрочено")
        #expect(overdue.isDanger)
        #expect(!overdue.isCollapsible)
        #expect(screen.groups.last?.isCollapsible == true)
    }

    @Test func emptyGroupsAreHidden() {
        let screen = screen([fixture.task("Завтра", due: "2026-11-09")])
        #expect(screen.groups.map(\.kind) == [.upcoming])
        #expect(screen.groups[0].count == 1)
    }

    @Test func groupsFollowClock() {
        let screen = screen([fixture.task("Задача", due: "2026-11-09")])
        #expect(screen.groups.map(\.kind) == [.upcoming])
        clock.advance(days: 1)
        #expect(screen.groups.map(\.kind) == [.today])
        clock.advance(days: 1)
        #expect(screen.groups.map(\.kind) == [.overdue])
    }

    @Test func sortByDatePutsUntimedFirst() {
        let screen = screen([
            fixture.task("10:00", due: "2026-11-09 10:00"),
            fixture.task("Без времени", due: "2026-11-09"),
            fixture.task("08:00", due: "2026-11-09 08:00"),
            fixture.task("Позже", due: "2026-11-12"),
        ])
        #expect(screen.sortTitle == "Дата")
        #expect(titles(screen, .upcoming) == ["Без времени", "08:00", "10:00", "Позже"])
    }

    @Test func sortByPriorityThenDate() {
        let screen = screen([
            fixture.task("Низкий рано", due: "2026-11-09", priority: .low),
            fixture.task("Высокий поздно", due: "2026-11-12", priority: .high),
            fixture.task("Высокий рано", due: "2026-11-10", priority: .high),
            fixture.task("Без приоритета", due: "2026-11-09"),
        ])
        screen.toggleSort()
        #expect(screen.sortTitle == "Приоритет")
        #expect(titles(screen, .upcoming) == ["Высокий рано", "Высокий поздно", "Низкий рано", "Без приоритета"])
        screen.toggleSort()
        #expect(titles(screen, .upcoming).first == "Низкий рано")
    }

    @Test func completedGroupCollapses() throws {
        let screen = screen([fixture.task("Сделано", completed: true)])
        var group = try #require(screen.groups.first)
        #expect(group.toggleTitle == "Скрыть")
        #expect(group.rows.count == 1)

        screen.toggleCompletedGroup()
        group = try #require(screen.groups.first)
        #expect(group.rows.isEmpty)
        #expect(group.count == 1)
        #expect(group.toggleTitle == "Показать")
    }

    // MARK: - Поиск и фильтр

    @Test func queryFiltersByTitle() {
        let screen = screen([fixture.task("Купить молоко"), fixture.task("Позвонить маме")])
        screen.query = "  МОЛОКО "
        #expect(screen.hasQuery)
        #expect(screen.trimmedQueryText == "МОЛОКО")
        #expect(titles(screen, .undated) == ["Купить молоко"])
        #expect(!screen.showsNoResults)

        screen.query = "хлеб"
        #expect(screen.groups.isEmpty)
        #expect(screen.showsNoResults)

        screen.clearQuery()
        #expect(!screen.hasQuery)
        #expect(screen.groups.first?.rows.count == 2)
    }

    @Test func categoryChips() {
        let work = fixture.list("Работа", color: "#111111")
        let home = fixture.list("Дом", color: "#222222")
        let screen = screen([fixture.task("Отчёт", list: work), fixture.task("Уборка", list: home)], lists: [work, home])

        #expect(screen.categoryChips.map(\.title) == ["Все", "Работа", "Дом"])
        #expect(screen.categoryChips.filter(\.isSelected).map(\.title) == ["Все"])

        screen.selectCategory(work.id)
        #expect(screen.categoryChips.filter(\.isSelected).map(\.title) == ["Работа"])
        #expect(titles(screen, .undated) == ["Отчёт"])

        screen.selectCategory(nil)
        #expect(filter.categoryIDs.isEmpty)
        #expect(titles(screen, .undated).count == 2)
    }

    @Test func emptyStates() {
        let empty = screen()
        #expect(empty.showsNoTasks)
        #expect(!empty.hasAnyTasks)
        empty.query = "что-то"
        // Нет задач вообще — показываем пустой экран, а не «ничего не найдено».
        #expect(!empty.showsNoResults)
    }

    // MARK: - Сводка и вид

    @Test func todaySummary() {
        let screen = screen([
            fixture.task("A", due: "2026-11-08", completed: true),
            fixture.task("B", due: "2026-11-08 18:00"),
            fixture.task("C", due: "2026-11-07", endDay: "2026-11-09"),
            fixture.task("D", due: "2026-11-09"),
        ])
        #expect(screen.todaySummary == "1 из 3 выполнено")
        #expect(abs(screen.todayProgress - 1.0 / 3) < 0.0001)
    }

    @Test func noTasksTodayHasZeroProgress() {
        #expect(screen([fixture.task(due: "2026-11-09")]).todayProgress == 0)
    }

    @Test func densityToggle() {
        let screen = screen()
        #expect(!screen.isCompact)
        #expect(screen.densityToggleTitle == "Компактный вид")
        screen.toggleDensity()
        #expect(screen.isCompact)
        #expect(screen.densityToggleTitle == "Обычный вид")
    }

    // MARK: - Действия

    @Test func toggleCompletesWithUndo() {
        let task = fixture.task("Отчёт", due: "2026-11-08")
        let screen = screen([task])
        screen.toggle(task.id)
        #expect(repository.completions.map(\.isCompleted) == [true])
        #expect(toasts.current?.message == "Выполнено «Отчёт»")

        toasts.performUndo()
        #expect(repository.restoredIDs == [task.id])
    }

    @Test func undoOfRecurringCompletionRemovesNextOccurrence() {
        let task = fixture.task("Пробежка", due: "2026-11-08", repeatRule: .daily)
        let next = fixture.task("Пробежка", due: "2026-11-09", repeatRule: .daily)
        repository.nextOccurrence = next
        let screen = screen([task])
        screen.toggle(task.id)
        toasts.performUndo()
        #expect(repository.deletedIDs == [next.id])
        #expect(repository.restoredIDs == [task.id])
    }

    @Test func uncompletingShowsNoToast() {
        let task = fixture.task("Отчёт", completed: true)
        let screen = screen([task])
        screen.toggle(task.id)
        #expect(repository.completions.map(\.isCompleted) == [false])
        #expect(toasts.current == nil)
    }

    @Test func openAndCreate() {
        let task = fixture.task("Отчёт")
        let screen = screen([task])
        screen.open(task.id)
        #expect(screen.editorRequest?.task === task)

        screen.startCreating()
        #expect(screen.editorRequest?.task == nil)
        #expect(screen.editorRequest?.day == date("2026-11-08"))
        #expect(screen.editorRequest?.startMinute == nil)

        screen.editorRequest = nil
        screen.open(UUID())
        screen.toggle(UUID())
        #expect(screen.editorRequest == nil)
        #expect(repository.completions.isEmpty)
    }

    @Test func groupTitles() {
        #expect(TasksViewModel.GroupKind.allCases.map(\.title) == ["Просрочено", "Сегодня", "Предстоящие", "Без даты", "Выполнено"])
    }
}
