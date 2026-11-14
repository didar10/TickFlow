import Foundation
import Observation

/// Переход к истории фокуса из профиля, аналитики и экрана фокуса.
enum FocusRoute: Hashable {
    case history
}

/// «История фокуса»: итоги недели, фильтр по статусу и записи по дням.
@MainActor
@Observable
final class FocusHistoryViewModel {
    enum Filter: Hashable, CaseIterable {
        case all, completed, interrupted, cancelled

        var title: String {
            switch self {
            case .all: L10n.Common.all
            case .completed: L10n.Focus.filterCompleted
            case .interrupted: L10n.Focus.filterInterrupted
            case .cancelled: L10n.Focus.filterCancelled
            }
        }

        func matches(_ entry: TimeEntry) -> Bool {
            switch self {
            case .all: true
            case .completed: entry.status == .completed
            case .interrupted: entry.status == .interrupted
            case .cancelled: entry.status == .cancelled
            }
        }
    }

    struct Stat: Identifiable {
        var id: String { title }
        let title: String
        let value: String
    }

    struct Day: Identifiable {
        let id: Date
        let title: String
        let summary: String
        let rows: [SessionRowItem]
    }

    /// Сколько дней видно, пока не нажата «Показать более ранние».
    static let initialDays = 7

    var filter: Filter = .all {
        didSet { showsAll = false }
    }
    private(set) var showsAll = false
    var sessionDetail: SessionDetailViewModel?
    var editorRequest: TaskEditorRequest?
    @ObservationIgnored private var taskAfterSession: TaskItem?

    @ObservationIgnored private let entries: any TimeEntryRepository
    @ObservationIgnored private let settings: any SettingsRepository
    @ObservationIgnored private let clock: any AppClock
    @ObservationIgnored private let makeSessionDetail: ((TimeEntry, @escaping (TaskItem) -> Void) -> SessionDetailViewModel)?

    init(
        entries: any TimeEntryRepository,
        settings: any SettingsRepository,
        makeSessionDetail: ((TimeEntry, @escaping (TaskItem) -> Void) -> SessionDetailViewModel)? = nil,
        clock: any AppClock = SystemClock()
    ) {
        self.entries = entries
        self.settings = settings
        self.makeSessionDetail = makeSessionDetail
        self.clock = clock
    }

    private var format: DisplayFormatter { DisplayFormatter(settings: settings.settings, clock: clock) }

    /// Записи без перерывов.
    private var sessions: [TimeEntry] { entries.entries.filter { $0.kind != .breakTime } }

    private var lastWeek: [TimeEntry] {
        let format = format
        guard let start = format.calendar.date(byAdding: .day, value: -6, to: format.today) else { return [] }
        return sessions.filter { $0.countsAsWork && $0.start >= start }
    }

    private func minutes(_ entries: [TimeEntry]) -> Int { entries.reduce(0) { $0 + $1.durationMinutes } }

    var stats: [Stat] {
        let format = format
        let week = lastWeek
        let today = week.filter { format.calendar.isDate($0.start, inSameDayAs: format.today) }
        return [
            Stat(title: L10n.Common.today, value: DateFormatting.duration(minutes: minutes(today))),
            Stat(title: L10n.Focus.last7Days, value: DateFormatting.duration(minutes: minutes(week))),
            Stat(title: L10n.Focus.sessionsStat, value: String(week.count)),
        ]
    }

    /// Последние 7 дней, сегодня — последний столбик.
    var bars: [(id: Int, label: String, minutes: Int, isCurrent: Bool)] {
        let format = format
        let calendar = format.calendar
        let week = lastWeek
        let letters = calendar.veryShortStandaloneWeekdaySymbols
        return (0..<7).compactMap { index in
            guard let day = calendar.date(byAdding: .day, value: index - 6, to: format.today) else { return nil }
            let total = minutes(week.filter { calendar.isDate($0.start, inSameDayAs: day) })
            return (index, letters[calendar.component(.weekday, from: day) - 1], total, index == 6)
        }
    }

    var maxBar: Int { max(1, bars.map(\.minutes).max() ?? 1) }

    private var allDays: [Day] {
        let format = format
        let calendar = format.calendar
        let filtered = sessions.filter(filter.matches)
        let grouped = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.start) }
        return grouped.keys.sorted(by: >).map { day in
            let entries = (grouped[day] ?? []).sorted { $0.start > $1.start }
            let worked = minutes(entries.filter { $0.status != .cancelled })
            return Day(
                id: day,
                title: format.relativeDay(day),
                summary: L10n.Calendar.trackedTotal(DateFormatting.duration(minutes: worked), L10n.Focus.sessions(entries.count)),
                rows: entries.map { SessionRowItem(entry: $0, format: format) }
            )
        }
    }

    var days: [Day] {
        let days = allDays
        return showsAll ? days : Array(days.prefix(Self.initialDays))
    }

    var isEmpty: Bool { allDays.isEmpty }
    var hasMore: Bool { !showsAll && allDays.count > Self.initialDays }

    func showEarlier() { showsAll = true }

    func open(_ id: UUID) {
        guard let makeSessionDetail, let entry = entries.entries.first(where: { $0.id == id }) else { return }
        sessionDetail = makeSessionDetail(entry) { [weak self] in self?.taskAfterSession = $0 }
    }

    /// Лист сессии закрыт: если в нём нажали «Открыть задачу», показать редактор.
    func sessionClosed() {
        sessionDetail = nil
        if let task = taskAfterSession {
            taskAfterSession = nil
            editorRequest = .edit(task)
        }
    }
}
