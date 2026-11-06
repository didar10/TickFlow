import Foundation
import Observation

/// Создание и редактирование задачи. Новая задача попадает в базу только после `save()`.
@MainActor
@Observable
final class TaskEditorViewModel {
    var title = ""
    var notes = ""
    var hasDueDate = false
    var dueDate = Date.now
    private(set) var hasTime = false
    var priority: Priority = .none
    var selectedListID: UUID?
    var subtasks: [SubtaskDraft] = []
    var newSubtaskTitle = ""
    private var durationMinutes = 60

    let task: TaskItem?

    @ObservationIgnored private let taskRepository: any TaskRepository
    @ObservationIgnored private let listRepository: any TaskListRepository
    @ObservationIgnored private let calendar = Calendar.current

    init(
        task: TaskItem?,
        defaultList: TaskList?,
        defaultDueDate: Date?,
        defaultHasTime: Bool,
        tasks: any TaskRepository,
        lists: any TaskListRepository
    ) {
        self.task = task
        taskRepository = tasks
        listRepository = lists

        if let task {
            title = task.title
            notes = task.notes
            hasDueDate = task.dueDate != nil
            dueDate = task.dueDate ?? defaultDueDate ?? .now
            hasTime = task.hasTime
            durationMinutes = task.durationMinutes
            priority = task.priority
            selectedListID = task.list?.id
            subtasks = task.sortedSubtasks.map {
                SubtaskDraft(id: $0.id, title: $0.title, isCompleted: $0.isCompleted)
            }
        } else {
            hasDueDate = defaultDueDate != nil
            dueDate = defaultDueDate ?? .now
            hasTime = defaultHasTime
            selectedListID = defaultList?.id ?? lists.lists.first?.id
        }
    }

    // MARK: - Данные

    var lists: [TaskList] {
        listRepository.lists
    }

    var isExisting: Bool {
        task != nil
    }

    var navigationTitle: String {
        isExisting ? "Задача" : "Новая задача"
    }

    var canSave: Bool {
        !trimmedTitle.isEmpty
    }

    /// При включении времени у даты без времени подставляем ближайший час, а не полночь.
    var isTimeEnabled: Bool {
        get { hasTime }
        set {
            hasTime = newValue
            guard newValue, dueDate == calendar.startOfDay(for: dueDate) else { return }
            let nextHour = calendar.component(.hour, from: .now) + 1
            dueDate = calendar.date(byAdding: .hour, value: min(nextHour, 23), to: dueDate) ?? dueDate
        }
    }

    /// Конец раньше начала означает переход через полночь.
    var endTime: Date {
        get { dueDate.addingTimeInterval(TimeInterval(durationMinutes * 60)) }
        set {
            let end = calendar.dateComponents([.hour, .minute], from: newValue)
            let start = calendar.dateComponents([.hour, .minute], from: dueDate)
            let minutes = ((end.hour ?? 0) - (start.hour ?? 0)) * 60 + (end.minute ?? 0) - (start.minute ?? 0)
            durationMinutes = minutes > 0 ? minutes : minutes + 24 * 60
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Подзадачи

    func addSubtask() {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        subtasks.append(SubtaskDraft(id: UUID(), title: trimmed, isCompleted: false))
        newSubtaskTitle = ""
    }

    func removeSubtasks(at offsets: IndexSet) {
        subtasks.remove(atOffsets: offsets)
    }

    // MARK: - Сохранение

    func save() {
        addSubtask()
        guard canSave else { return }

        let draft = TaskDraft(
            title: trimmedTitle,
            notes: notes,
            dueDate: hasDueDate ? (hasTime ? dueDate : calendar.startOfDay(for: dueDate)) : nil,
            hasTime: hasDueDate && hasTime,
            durationMinutes: durationMinutes,
            priority: priority,
            list: listRepository.lists.first { $0.id == selectedListID },
            subtasks: subtasks.filter {
                !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        )
        taskRepository.save(draft, to: task)
    }

    func deleteTask() {
        guard let task else { return }
        taskRepository.delete(task)
    }
}
