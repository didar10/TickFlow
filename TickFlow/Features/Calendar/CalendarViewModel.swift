import Foundation
import Observation

@MainActor
@Observable
final class CalendarViewModel {
    /// Параметры создаваемой задачи: день из календаря или время из таймлайна.
    struct NewTaskRequest: Identifiable {
        let id = UUID()
        let date: Date
        let hasTime: Bool
    }

    var mode: CalendarMode {
        didSet {
            defaults.set(mode.rawValue, forKey: Self.modeKey)
            displayedMonth = selectedDate
        }
    }
    var selectedDate: Date {
        didSet {
            if !calendar.isDate(selectedDate, equalTo: displayedMonth, toGranularity: .month) {
                displayedMonth = selectedDate
            }
        }
    }
    private(set) var displayedMonth: Date
    var editingTask: TaskItem?
    var newTask: NewTaskRequest?

    private static let modeKey = "calendarMode"

    @ObservationIgnored private let taskRepository: any TaskRepository
    @ObservationIgnored private let listRepository: any TaskListRepository
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar = Calendar.current

    init(tasks: any TaskRepository, lists: any TaskListRepository, defaults: UserDefaults = .standard) {
        taskRepository = tasks
        listRepository = lists
        self.defaults = defaults
        mode = defaults.string(forKey: Self.modeKey).flatMap(CalendarMode.init(rawValue:)) ?? .month
        let today = Calendar.current.startOfDay(for: .now)
        selectedDate = today
        displayedMonth = today
    }

    // MARK: - Данные

    var title: String {
        DateFormatting.monthTitle(for: displayedMonth)
    }

    var defaultList: TaskList? {
        listRepository.lists.first
    }

    var visibleDays: [Date] {
        let first = mode == .week
            ? calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            : selectedDate
        return (0..<mode.dayCount).compactMap {
            calendar.date(byAdding: .day, value: $0, to: first)
        }
    }

    /// Дни сетки месяца, включая края соседних месяцев.
    var monthDays: [Date] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
            let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
            let lastWeek = calendar.dateInterval(
                of: .weekOfMonth,
                for: monthInterval.end.addingTimeInterval(-1)
            )
        else { return [] }

        var result: [Date] = []
        var current = firstWeek.start
        while current < lastWeek.end {
            result.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return result
    }

    var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        guard shift > 0, shift < symbols.count else { return symbols }
        return Array(symbols[shift...] + symbols[..<shift])
    }

    /// Незавершённые задачи по дням (ключ — начало дня).
    var taskCounts: [Date: Int] {
        var result: [Date: Int] = [:]
        for task in taskRepository.tasks where !task.isCompleted {
            guard let due = task.dueDate else { continue }
            result[calendar.startOfDay(for: due), default: 0] += 1
        }
        return result
    }

    /// Сначала задачи на весь день, затем по времени.
    var tasksForSelectedDay: [TaskItem] {
        allDayTasks(on: selectedDate) + timedTasks(on: selectedDate)
    }

    func allDayTasks(on day: Date) -> [TaskItem] {
        tasks(on: day).filter { !$0.hasTime }
    }

    func timedTasks(on day: Date) -> [TaskItem] {
        tasks(on: day).filter(\.hasTime)
    }

    func placedTasks(on day: Date) -> [PlacedTask] {
        TimeGridLayout.place(timedTasks(on: day))
    }

    private func tasks(on day: Date) -> [TaskItem] {
        taskRepository.tasks
            .filter { task in
                guard let due = task.dueDate else { return false }
                return calendar.isDate(due, inSameDayAs: day)
            }
            .sorted { ($0.dueDate ?? .distantPast, $0.sortOrder) < ($1.dueDate ?? .distantPast, $1.sortOrder) }
    }

    // MARK: - Навигация

    func shift(by value: Int) {
        if mode == .month {
            displayedMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
        } else {
            selectedDate = calendar.date(byAdding: .day, value: value * mode.dayCount, to: selectedDate) ?? selectedDate
            displayedMonth = selectedDate
        }
    }

    func goToToday() {
        selectedDate = calendar.startOfDay(for: .now)
        displayedMonth = selectedDate
    }

    // MARK: - Создание

    func beginCreatingTask() {
        newTask = NewTaskRequest(date: selectedDate, hasTime: false)
    }

    /// Нажатие на свободное место шкалы: начало округляется вниз до получаса.
    func beginCreatingTask(on day: Date, atMinute minute: Int) {
        let start = calendar.date(byAdding: .minute, value: minute / 30 * 30, to: calendar.startOfDay(for: day))
        newTask = NewTaskRequest(date: start ?? day, hasTime: true)
    }

    // MARK: - Действия

    func toggle(_ task: TaskItem) {
        taskRepository.setCompleted(task, !task.isCompleted)
    }

    func delete(_ task: TaskItem) {
        taskRepository.delete(task)
    }

    func move(_ task: TaskItem, toDay day: Date, minute: Int) {
        guard let start = calendar.date(byAdding: .minute, value: minute, to: calendar.startOfDay(for: day)),
              start != task.dueDate || !task.hasTime
        else { return }
        taskRepository.schedule(task, at: start)
    }

    func resize(_ task: TaskItem, toMinutes minutes: Int) {
        guard minutes != task.durationMinutes else { return }
        taskRepository.setDuration(task, minutes: minutes)
    }
}
