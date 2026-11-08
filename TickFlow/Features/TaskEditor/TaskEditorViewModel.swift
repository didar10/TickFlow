import Foundation
import Observation

/// Что открыть в редакторе: существующую задачу или новую с подставленными значениями.
struct TaskEditorRequest: Identifiable {
    let id = UUID()
    var task: TaskItem?
    /// День новой задачи. `nil` — без даты.
    var day: Date?
    /// Начало в минутах от полуночи. `nil` — без времени.
    var startMinute: Int?
    var endDay: Date?
    var list: TaskList?
    var title = ""

    static func edit(_ task: TaskItem) -> TaskEditorRequest {
        TaskEditorRequest(task: task)
    }

    static func new(
        day: Date? = Calendar.current.startOfDay(for: .now),
        startMinute: Int? = nil,
        endDay: Date? = nil,
        list: TaskList? = nil
    ) -> TaskEditorRequest {
        TaskEditorRequest(task: nil, day: day, startMinute: startMinute, endDay: endDay, list: list)
    }
}

/// Быстрое создание и полноэкранное редактирование задачи.
/// Редактирует черновик: в базу попадает только по сохранению.
@MainActor
@Observable
final class TaskEditorViewModel {
    enum Mode { case quick, full }
    enum Field: Hashable { case title, notes, subtask }

    enum Dialog: Identifiable {
        case delete
        case conflict(message: String)
        case recurring(message: String)

        var id: String {
            switch self {
            case .delete: "delete"
            case .conflict: "conflict"
            case .recurring: "recurring"
            }
        }
    }

    struct CategoryOption: Identifiable {
        let id: UUID
        let name: String
        let colorHex: String
        let isSelected: Bool
    }

    struct PriorityOption: Identifiable {
        var id: Int { priority.rawValue }
        let priority: Priority
        let isSelected: Bool
    }

    var mode: Mode
    var title: String
    var notes: String
    var newSubtaskTitle = ""
    private(set) var subtasks: [SubtaskDraft]
    private(set) var schedule: DateSelection
    private(set) var priority: Priority
    private(set) var categoryID: UUID?
    private(set) var isCategoryExplicit: Bool
    private(set) var isCompleted: Bool
    var picker: DateTimePickerViewModel?
    var dialog: Dialog?
    /// Поле, на которое View должна перевести фокус.
    var focusRequest: Field?
    /// Работа закончена — View закрывает лист.
    private(set) var isFinished = false

    let task: TaskItem?

    @ObservationIgnored private let taskRepository: any TaskRepository
    @ObservationIgnored private let listRepository: any TaskListRepository
    @ObservationIgnored private let toasts: ToastCenter
    @ObservationIgnored private let format: DisplayFormatter
    @ObservationIgnored private let clock: any AppClock
    @ObservationIgnored private let original: TaskDraft?
    @ObservationIgnored private var pendingScope: RecurringScope?

    private var calendar: Calendar { format.calendar }

    init(
        request: TaskEditorRequest,
        settings: AppSettings,
        tasks: any TaskRepository,
        lists: any TaskListRepository,
        toasts: ToastCenter,
        clock: any AppClock = SystemClock()
    ) {
        let format = DisplayFormatter(settings: settings, clock: clock)
        self.clock = clock
        self.format = format
        taskRepository = tasks
        listRepository = lists
        self.toasts = toasts
        task = request.task

        if let task = request.task {
            mode = .full
            title = task.title
            notes = task.notes
            priority = task.priority
            categoryID = task.list?.id
            isCategoryExplicit = true
            isCompleted = task.isCompleted
            subtasks = task.sortedSubtasks.map { SubtaskDraft(id: $0.id, title: $0.title, isCompleted: $0.isCompleted) }
            schedule = Self.selection(for: task, format: format, defaultDuration: settings.defaultTaskDuration)
            original = TaskSnapshot(task).draft
        } else {
            mode = .quick
            title = request.title
            notes = ""
            priority = .none
            categoryID = request.list?.id ?? lists.lists.first?.id
            // Иконка категории остаётся серой, пока пользователь не выберет категорию сам.
            isCategoryExplicit = false
            isCompleted = false
            subtasks = []
            let day = request.day.map { format.calendar.startOfDay(for: $0) }
            let start = request.startMinute ?? 600
            schedule = DateSelection(
                day: day,
                endDay: request.endDay.map { format.calendar.startOfDay(for: $0) } ?? day ?? format.today,
                hasTime: request.startMinute != nil,
                startMinute: start,
                endMinute: min(1440, start + settings.defaultTaskDuration),
                reminder: request.startMinute != nil ? settings.defaultReminder : .none,
                repeatRule: .never,
                isPeriod: request.startMinute != nil || request.endDay != nil
            )
            original = nil
        }
        // Существующую задачу открываем без клавиатуры, чтобы были видны подзадачи.
        focusRequest = request.task == nil ? .title : nil
    }

    private static func selection(for task: TaskItem, format: DisplayFormatter, defaultDuration: Int) -> DateSelection {
        let calendar = format.calendar
        guard let due = task.dueDate else {
            return DateSelection(
                day: nil, endDay: format.today, hasTime: false, startMinute: 600,
                endMinute: 600 + defaultDuration, reminder: task.reminder, repeatRule: task.repeatRule, isPeriod: false
            )
        }
        let day = calendar.startOfDay(for: due)
        let start = task.hasTime ? format.minute(of: due) : 600
        var endDay = task.lastDay ?? day
        var endMinute = min(1440, start + (task.hasTime ? task.durationMinutes : defaultDuration))
        if task.hasTime, let end = task.endDate {
            endDay = calendar.startOfDay(for: end)
            endMinute = format.minute(of: end)
            // Конец ровно в полночь показываем как 24:00 предыдущего дня.
            if endMinute == 0, endDay > day {
                endDay = calendar.date(byAdding: .day, value: -1, to: endDay) ?? endDay
                endMinute = 1440
            }
        }
        return DateSelection(
            day: day, endDay: endDay, hasTime: task.hasTime, startMinute: start, endMinute: endMinute,
            reminder: task.reminder, repeatRule: task.repeatRule,
            isPeriod: task.hasTime
        )
    }

    // MARK: - Отображение

    var isEditing: Bool { task != nil }
    var hasDate: Bool { schedule.day != nil }
    var canSave: Bool { !trimmedTitle.isEmpty && !schedule.isInvalid(calendar: calendar) }

    /// Подпись срока в полноэкранном редакторе.
    var whenFull: String {
        guard let day = schedule.day else { return L10n.Editor.dateAndReminder }
        if schedule.isMultiDay(calendar: calendar) {
            guard schedule.hasTime else { return format.shortRange(day, schedule.endDay) }
            return format.relativeDay(day) + ", " + format.time(minute: schedule.startMinute)
                + " – " + format.relativeDay(schedule.endDay) + ", " + format.time(minute: schedule.endMinute)
        }
        guard schedule.hasTime else { return format.relativeDay(day) }
        let start = format.relativeDay(day) + ", " + format.time(minute: schedule.startMinute)
        return schedule.isPeriod ? start + " – " + format.time(minute: schedule.endMinute) : start
    }

    /// Подпись срока на чипе быстрого создания.
    var whenShort: String {
        guard let day = schedule.day else { return "" }
        if schedule.isMultiDay(calendar: calendar) { return format.shortRange(day, schedule.endDay) }
        return schedule.hasTime ? format.relativeDay(day) + ", " + format.time(minute: schedule.startMinute) : format.relativeDay(day)
    }

    var hasPriority: Bool { priority != .none }

    var hasReminderOrRepeat: Bool { schedule.reminder != .none || schedule.repeatRule != .never }

    var categories: [CategoryOption] {
        listRepository.lists.map {
            CategoryOption(id: $0.id, name: $0.name, colorHex: $0.colorHex, isSelected: $0.id == categoryID)
        }
    }

    var categoryName: String { selectedList?.name ?? L10n.Common.noCategory }
    var categoryColorHex: String { selectedList?.colorHex ?? AppColors.fallbackList }

    var priorities: [PriorityOption] {
        [Priority.high, .medium, .low, .none].map { PriorityOption(priority: $0, isSelected: $0 == priority) }
    }

    var subtaskCount: String {
        guard !subtasks.isEmpty else { return "" }
        return L10n.Common.ofTotal(subtasks.filter(\.isCompleted).count, subtasks.count)
    }

    var canAddSubtask: Bool { !newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private var selectedList: TaskList? {
        listRepository.lists.first { $0.id == categoryID }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Изменения

    func selectCategory(_ id: UUID) {
        categoryID = id
        isCategoryExplicit = true
    }

    func selectPriority(_ value: Priority) {
        priority = value
    }

    func toggleCompleted() {
        isCompleted.toggle()
    }

    /// Лист закрывается и открывается полноэкранный редактор с тем же черновиком.
    func openFullScreen() {
        mode = .full
        focusRequest = .title
    }

    func openPicker() {
        picker = DateTimePickerViewModel(
            selection: schedule,
            format: format,
            tasks: taskRepository.tasks,
            excluding: task?.id
        ) { [weak self] result in
            self?.schedule = result
            self?.picker = nil
        }
    }

    func closePicker() {
        picker = nil
    }

    /// Enter в названии: в быстром режиме сохраняет, в полном — переходит к описанию.
    func submitTitle() {
        if mode == .quick {
            save()
        } else {
            focusRequest = .notes
        }
    }

    // MARK: - Подзадачи

    func addSubtask() {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        subtasks.append(SubtaskDraft(id: UUID(), title: trimmed, isCompleted: false))
        newSubtaskTitle = ""
        focusRequest = .subtask
    }

    func toggleSubtask(_ id: UUID) {
        guard let index = subtasks.firstIndex(where: { $0.id == id }) else { return }
        subtasks[index].isCompleted.toggle()
    }

    func renameSubtask(_ id: UUID, to title: String) {
        guard let index = subtasks.firstIndex(where: { $0.id == id }) else { return }
        subtasks[index].title = title
    }

    func deleteSubtask(_ id: UUID) {
        subtasks.removeAll { $0.id == id }
    }

    func focusNewSubtask() {
        focusRequest = .subtask
    }

    // MARK: - Закрытие

    /// Кнопка «Назад» в полном режиме: непустая задача сохраняется, пустая отбрасывается.
    func back() {
        if trimmedTitle.isEmpty {
            isFinished = true
        } else {
            save()
        }
    }

    func discard() {
        isFinished = true
    }

    // MARK: - Сохранение

    func save() {
        addSubtask()
        guard canSave else { return }
        let draft = makeDraft()

        guard let task, let original else {
            create(draft)
            return
        }

        guard draft != original || isCompleted != task.isCompleted else {
            isFinished = true
            return
        }

        let scheduleChanged = !draft.hasSameSchedule(as: original)
        if scheduleChanged, task.repeatRule != .never {
            dialog = .recurring(message: ScheduleCommit.recurringMessage(title: draft.title, rule: task.repeatRule))
            return
        }
        if scheduleChanged, let message = conflictMessage(for: draft) {
            dialog = .conflict(message: message)
            return
        }
        commitEdit(draft, scope: nil)
    }

    func resolveRecurring(_ scope: RecurringScope) {
        dialog = nil
        let draft = makeDraft()
        if let message = conflictMessage(for: draft) {
            pendingScope = scope
            dialog = .conflict(message: message)
            return
        }
        commitEdit(draft, scope: scope)
    }

    /// «Оставить обе» в предупреждении о пересечении.
    func confirmConflict() {
        dialog = nil
        commitEdit(makeDraft(), scope: pendingScope)
        pendingScope = nil
    }

    func cancelDialog() {
        dialog = nil
        pendingScope = nil
    }

    // MARK: - Меню «Ещё»

    func duplicate() {
        guard let task else { return }
        let copy = taskRepository.duplicate(task)
        toasts.show(L10n.Editor.copyCreated) { [taskRepository] in
            taskRepository.delete(copy)
        }
    }

    func requestDelete() {
        dialog = .delete
    }

    func confirmDelete() {
        dialog = nil
        guard let task else { return }
        let snapshot = TaskSnapshot(task)
        taskRepository.delete(task)
        isFinished = true
        toasts.show(L10n.Tasks.deleted) { [taskRepository] in
            taskRepository.restore(snapshot)
        }
    }

    // MARK: - Внутреннее

    private func create(_ draft: TaskDraft) {
        let item = taskRepository.save(draft, to: nil)
        isFinished = true
        var message = L10n.Editor.addedToast(draft.dueDate == nil ? L10n.Common.noDate : whenShort)
        if let conflict = ConflictDetector.conflict(for: item, in: taskRepository.tasks) {
            message += " · " + L10n.Editor.overlapsWith(conflict.title)
        }
        toasts.show(message) { [taskRepository] in
            taskRepository.delete(item)
        }
    }

    private func commitEdit(_ draft: TaskDraft, scope: RecurringScope?) {
        guard let task else { return }
        var draft = draft
        // Флаг выполнения применяем отдельно: для повторяющейся задачи это создаст следующее вхождение.
        draft.isCompleted = task.isCompleted
        let undoSchedule = ScheduleCommit.commit(draft, to: task, scope: scope, repository: taskRepository)

        var next: TaskItem?
        if isCompleted != task.isCompleted {
            next = taskRepository.setCompleted(task, isCompleted)
        }
        isFinished = true

        let message = scope == .thisOccurrence ? L10n.Editor.changesSavedThisOccurrence : L10n.Editor.changesSaved
        toasts.show(message) { [taskRepository] in
            if let next { taskRepository.delete(next) }
            undoSchedule()
        }
    }

    private func conflictMessage(for draft: TaskDraft) -> String? {
        guard draft.hasTime, draft.endDay == nil, let start = draft.dueDate else { return nil }
        let end = start.addingTimeInterval(TimeInterval(draft.durationMinutes * 60))
        guard let other = ConflictDetector.conflict(start: start, end: end, excluding: task?.id, in: taskRepository.tasks),
              let otherStart = other.dueDate, let otherEnd = other.endDate
        else { return nil }
        return L10n.Common.overlapMessage(draft.title, other.title, format.time(otherStart), format.time(otherEnd))
    }

    private func makeDraft() -> TaskDraft {
        let start = schedule.hasTime ? schedule.startDate(calendar: calendar) : schedule.day
        let multiDay = schedule.isMultiDay(calendar: calendar)
        return TaskDraft(
            title: trimmedTitle,
            notes: notes,
            dueDate: start,
            hasTime: schedule.day != nil && schedule.hasTime,
            durationMinutes: schedule.hasTime ? schedule.durationMinutes : (task?.durationMinutes ?? 60),
            endDay: schedule.day != nil && multiDay ? schedule.endDay : nil,
            priority: priority,
            reminder: schedule.day != nil ? schedule.reminder : .none,
            repeatRule: schedule.day != nil ? schedule.repeatRule : .never,
            list: selectedList,
            subtasks: subtasks.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            isCompleted: isCompleted
        )
    }
}

extension TaskDraft: Equatable {
    static func == (lhs: TaskDraft, rhs: TaskDraft) -> Bool {
        lhs.title == rhs.title && lhs.notes == rhs.notes && lhs.hasSameSchedule(as: rhs)
            && lhs.priority == rhs.priority && lhs.reminder == rhs.reminder && lhs.repeatRule == rhs.repeatRule
            && lhs.list?.id == rhs.list?.id && lhs.subtasks == rhs.subtasks && lhs.isCompleted == rhs.isCompleted
    }

    /// Совпадают ли дата, время, длительность и последний день.
    func hasSameSchedule(as other: TaskDraft) -> Bool {
        let calendar = Calendar.current
        func sameDay(_ a: Date?, _ b: Date?) -> Bool {
            switch (a, b) {
            case (nil, nil): true
            case let (a?, b?): calendar.isDate(a, inSameDayAs: b)
            default: false
            }
        }
        guard hasTime == other.hasTime, sameDay(endDay, other.endDay) else { return false }
        if hasTime {
            return dueDate == other.dueDate && durationMinutes == other.durationMinutes
        }
        return sameDay(dueDate, other.dueDate)
    }
}
