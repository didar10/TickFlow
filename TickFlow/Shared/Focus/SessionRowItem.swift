import Foundation

/// Строка записи в «Учтённом времени» календаря и в истории фокуса.
struct SessionRowItem: Identifiable, Equatable {
    enum Badge: Equatable {
        case interrupted
        case cancelled
        case live
    }

    let id: UUID
    let title: String
    /// «08:00 – 08:25 · Фокус».
    let time: String
    let duration: String
    let kind: TimeEntryKind
    let colorHex: String?
    let hasTask: Bool
    let badge: Badge?

    var isCancelled: Bool { badge == .cancelled }

    var badgeText: String? {
        switch badge {
        case .interrupted: FocusText.status(.interrupted)
        case .cancelled: FocusText.status(.cancelled)
        case .live: L10n.Calendar.inProgress
        case nil: nil
        }
    }

    @MainActor
    init(entry: TimeEntry, format: DisplayFormatter) {
        id = entry.id
        title = SessionDetailViewModel.title(for: entry)
        time = format.time(entry.start) + " – " + format.time(entry.end) + " · " + FocusText.kind(entry.kind)
        duration = DateFormatting.duration(minutes: entry.durationMinutes)
        kind = entry.kind
        colorHex = entry.task?.list?.colorHex
        hasTask = entry.task != nil
        badge = switch entry.status {
        case .completed: nil
        case .interrupted: .interrupted
        case .cancelled: .cancelled
        }
    }

    init(id: UUID, title: String, time: String, duration: String, kind: TimeEntryKind,
         colorHex: String?, hasTask: Bool, badge: Badge?) {
        self.id = id
        self.title = title
        self.time = time
        self.duration = duration
        self.kind = kind
        self.colorHex = colorHex
        self.hasTask = hasTask
        self.badge = badge
    }
}
