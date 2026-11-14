import Foundation
import Observation

/// Лист «Сессия»: фактическое время записи и план задачи, переход к правке и удаление.
@MainActor
@Observable
final class SessionDetailViewModel: Identifiable {
    struct Pill: Identifiable, Equatable {
        enum Style: Equatable {
            case category(String)
            case accent
            case success
            case warning
            case neutral
        }

        var id: String { text }
        let text: String
        let style: Style
    }

    struct Row: Identifiable, Equatable {
        var id: String { title }
        let title: String
        let value: String
    }

    let id = UUID()
    let entry: TimeEntry
    var editor: TimeEntryEditorViewModel?
    private(set) var isFinished = false

    @ObservationIgnored private let entries: any TimeEntryRepository
    @ObservationIgnored private let toasts: ToastCenter
    @ObservationIgnored private let format: DisplayFormatter
    @ObservationIgnored private let makeEntryEditor: TimeEntryEditorFactory
    @ObservationIgnored private let onOpenTask: ((TaskItem) -> Void)?

    init(
        entry: TimeEntry,
        entries: any TimeEntryRepository,
        toasts: ToastCenter,
        format: DisplayFormatter,
        makeEntryEditor: @escaping TimeEntryEditorFactory,
        onOpenTask: ((TaskItem) -> Void)? = nil
    ) {
        self.entry = entry
        self.entries = entries
        self.toasts = toasts
        self.format = format
        self.makeEntryEditor = makeEntryEditor
        self.onOpenTask = onOpenTask
    }

    var title: String { Self.title(for: entry) }

    /// Название записи: задача, «Ручная запись» или «Сессия фокуса».
    static func title(for entry: TimeEntry) -> String {
        if let task = entry.task { return task.title }
        return entry.kind == .manual ? L10n.Focus.manualEntry : L10n.Focus.focusSession
    }

    var pills: [Pill] {
        var pills: [Pill] = []
        if let list = entry.task?.list { pills.append(Pill(text: list.name, style: .category(list.colorHex))) }
        pills.append(Pill(text: FocusText.kind(entry.kind), style: .accent))
        let style: Pill.Style = switch entry.status {
        case .completed: .success
        case .interrupted: .warning
        case .cancelled: .neutral
        }
        pills.append(Pill(text: FocusText.status(entry.status), style: style))
        return pills
    }

    var actualRows: [Row] {
        [
            Row(title: L10n.Common.date, value: format.fullDay(entry.start)),
            Row(title: L10n.Common.start, value: format.time(entry.start)),
            Row(title: L10n.Common.end, value: format.time(entry.end)),
            Row(title: L10n.Focus.duration, value: DateFormatting.duration(minutes: entry.durationMinutes)),
        ]
    }

    /// План задачи: запланированный слот и всего потрачено. Без задачи плана нет.
    var planRows: [Row] {
        guard let task = entry.task else { return [] }
        var rows: [Row] = []
        if let due = task.dueDate, let end = task.endDate, task.endDay == nil {
            rows.append(Row(title: L10n.Common.planned, value: format.relativeDay(due) + ", " + format.time(due) + " – " + format.time(end)))
        }
        let tracked = DateFormatting.duration(minutes: task.trackedMinutes)
        let total = task.effectiveEstimate.map { L10n.Focus.totalOf(tracked, DateFormatting.duration(minutes: $0)) } ?? tracked
        rows.append(Row(title: L10n.Focus.totalOnTask, value: total))
        return rows
    }

    var canOpenTask: Bool { entry.task != nil && onOpenTask != nil }

    func edit() {
        editor = makeEntryEditor(.edit(entry), entry.task, entry.start, entry.end)
    }

    /// Правка закончена: удалённая запись закрывает и этот лист.
    func editorClosed() {
        if editor?.didDelete == true { isFinished = true }
        editor = nil
    }

    func openTask() {
        guard let task = entry.task else { return }
        isFinished = true
        onOpenTask?(task)
    }

    func delete() {
        entries.delete(entry)
        toasts.show(L10n.Focus.sessionDeletedToast)
        isFinished = true
    }
}
