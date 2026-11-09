import Foundation
import Observation

/// Лист записи времени: ручная запись, правка существующей или сохранение остановленного таймера.
@MainActor
@Observable
final class TimeEntryEditorViewModel: Identifiable {
    enum Mode {
        /// Новая ручная запись.
        case new
        case edit(TimeEntry)
        /// Таймер остановлен: времена можно поправить перед сохранением.
        case fromTimer
    }

    let id = UUID()
    let mode: Mode
    private(set) var task: TaskItem?
    /// Начало дня записи.
    private(set) var day: Date
    private(set) var startMinute: Int
    private(set) var endMinute: Int
    var isTaskPickerPresented = false
    private(set) var isFinished = false
    /// Запись удалена: лист сессии, из которого открыта правка, тоже закрывается.
    private(set) var didDelete = false

    @ObservationIgnored private let entries: any TimeEntryRepository
    @ObservationIgnored private let tasks: any TaskRepository
    @ObservationIgnored private let focus: FocusEngine?
    @ObservationIgnored private let toasts: ToastCenter
    @ObservationIgnored private let format: DisplayFormatter

    init(
        mode: Mode,
        task: TaskItem?,
        start: Date,
        end: Date,
        entries: any TimeEntryRepository,
        tasks: any TaskRepository,
        focus: FocusEngine?,
        toasts: ToastCenter,
        format: DisplayFormatter
    ) {
        self.mode = mode
        self.task = task
        self.entries = entries
        self.tasks = tasks
        self.focus = focus
        self.toasts = toasts
        self.format = format
        let calendar = format.calendar
        day = calendar.startOfDay(for: start)
        startMinute = format.minute(of: start)
        // Запись через полночь обрезается концом дня.
        endMinute = calendar.isDate(end, inSameDayAs: start) ? format.minute(of: end) : 1439
    }

    // MARK: - Тексты

    var title: String {
        switch mode {
        case .new: L10n.Focus.addTime
        case .edit: L10n.Focus.editEntry
        case .fromTimer: L10n.Focus.saveTime
        }
    }

    var taskTitle: String { task?.title ?? L10n.Common.none }
    var hasTask: Bool { task != nil }
    var dayText: String { format.relativeDay(day) }
    var startText: String { format.time(minute: startMinute) }
    var endText: String { format.time(minute: endMinute) }
    var isValid: Bool { endMinute > startMinute }
    var durationText: String { isValid ? DateFormatting.duration(minutes: endMinute - startMinute) : L10n.Common.dash }
    var errorText: String? { isValid ? nil : L10n.Focus.endBeforeStart }
    var canStepDayForward: Bool { day < format.today }

    var footnote: String? {
        switch mode {
        case .new: L10n.Focus.footManual
        case .edit: nil
        case .fromTimer: L10n.Focus.footTimer
        }
    }

    var canDelete: Bool { if case .edit = mode { true } else { false } }
    var canDiscard: Bool { if case .fromTimer = mode { true } else { false } }

    // MARK: - Изменения

    /// День меняется шагом; будущих дней нет.
    func stepDay(_ delta: Int) {
        guard let next = format.calendar.date(byAdding: .day, value: delta, to: day) else { return }
        day = min(next, format.today)
    }

    func stepStart(_ delta: Int) {
        startMinute = min(1435, max(0, startMinute + delta))
    }

    func stepEnd(_ delta: Int) {
        endMinute = min(1439, max(5, endMinute + delta))
    }

    func selectTask(_ task: TaskItem?) {
        self.task = task
        isTaskPickerPresented = false
    }

    var taskOptions: [TaskPickerOption] { TaskPickerOption.options(from: tasks.tasks, format: format) }

    func selectTask(id: UUID?) {
        selectTask(id.flatMap { id in tasks.tasks.first { $0.id == id } })
    }

    // MARK: - Действия

    func save() {
        guard isValid else { return }
        let draft = makeDraft()
        let duration = DateFormatting.duration(minutes: endMinute - startMinute)
        switch mode {
        case .new:
            entries.add(draft)
            toasts.show(L10n.Focus.entrySavedToast(duration))
        case .edit(let entry):
            entries.update(entry, with: draft)
            toasts.show(L10n.Focus.entryUpdatedToast(duration))
        case .fromTimer:
            focus?.finishTimer(draft)
            toasts.show(L10n.Focus.entrySavedToast(duration))
        }
        isFinished = true
    }

    /// «Отмена». Остановленный таймер продолжает идти.
    func cancel() {
        if case .fromTimer = mode { focus?.continueTimer() }
        isFinished = true
    }

    func delete() {
        guard case .edit(let entry) = mode else { return }
        entries.delete(entry)
        toasts.show(L10n.Focus.entryDeletedToast)
        didDelete = true
        isFinished = true
    }

    /// «Не сохранять» для таймера: запись остаётся отброшенной.
    func discard() {
        guard case .fromTimer = mode else { return }
        let draft = makeDraft()
        focus?.discardTimer(start: draft.start, end: draft.end)
        isFinished = true
    }

    private func makeDraft() -> TimeEntryDraft {
        let start = day.addingTimeInterval(TimeInterval(startMinute * 60))
        let end = day.addingTimeInterval(TimeInterval(endMinute * 60))
        let kind: TimeEntryKind
        let status: TimeEntryStatus
        switch mode {
        case .new: (kind, status) = (.manual, .completed)
        case .edit(let entry): (kind, status) = (entry.kind, entry.status)
        case .fromTimer: (kind, status) = (.timer, .completed)
        }
        return TimeEntryDraft(task: task, start: start, end: end, kind: kind, status: status)
    }
}

/// Строка выбора задачи для сессии или записи.
struct TaskPickerOption: Identifiable, Equatable {
    let id: UUID
    let title: String
    let colorHex: String
    /// «Сегодня», «Пт, 13 нояб.» или «Без даты».
    let when: String

    /// Невыполненные задачи: сначала с датой по порядку, затем без даты. Не больше `limit`.
    @MainActor
    static func options(from tasks: [TaskItem], format: DisplayFormatter, limit: Int = 12) -> [TaskPickerOption] {
        tasks
            .filter { !$0.isCompleted }
            .sorted { lhs, rhs in
                switch (lhs.dueDate, rhs.dueDate) {
                case let (l?, r?): l < r
                case (_?, nil): true
                case (nil, _?): false
                case (nil, nil): lhs.sortOrder < rhs.sortOrder
                }
            }
            .prefix(limit)
            .map {
                TaskPickerOption(
                    id: $0.id,
                    title: $0.title,
                    colorHex: $0.list?.colorHex ?? AppColors.fallbackList,
                    when: $0.dueDate.map(format.relativeDay) ?? L10n.Common.noDate
                )
            }
    }
}
