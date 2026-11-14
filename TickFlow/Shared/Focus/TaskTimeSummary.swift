import Foundation

/// Потраченное время задачи против оценки: для блока «Потрачено» в редакторе.
struct TaskTimeSummary: Equatable {
    let trackedMinutes: Int
    let estimateMinutes: Int?

    var isOver: Bool { estimateMinutes.map { trackedMinutes > $0 } ?? false }

    /// Заполнение полосы, 0…1. Без оценки полоса полная, если время уже есть.
    var progress: Double {
        guard let estimateMinutes, estimateMinutes > 0 else { return trackedMinutes > 0 ? 1 : 0 }
        return min(1, Double(trackedMinutes) / Double(estimateMinutes))
    }

    /// «1 ч 10 мин потрачено».
    var summary: String { L10n.Focus.trackedSummary(DateFormatting.duration(minutes: trackedMinutes)) }

    /// «Осталось 20 мин», «15 мин сверх оценки» или «Без оценки».
    var balance: String {
        guard let estimateMinutes else { return L10n.Focus.noEstimate }
        let difference = abs(estimateMinutes - trackedMinutes)
        return isOver
            ? L10n.Focus.overEstimate(DateFormatting.duration(minutes: difference))
            : L10n.Focus.timeLeft(DateFormatting.duration(minutes: difference))
    }

    var estimateText: String {
        estimateMinutes.map { DateFormatting.duration(minutes: $0) } ?? L10n.Common.none
    }
}

/// Строка записи времени в истории задачи или дня.
struct TimeEntryRow: Identifiable, Equatable {
    let id: UUID
    /// «Сегодня, 9:00 – 9:25».
    let title: String
    /// «Фокус · Прервана».
    let subtitle: String
    let duration: String
    let kind: TimeEntryKind
    let isCancelled: Bool

    @MainActor
    init(entry: TimeEntry, format: DisplayFormatter) {
        id = entry.id
        title = format.relativeDay(entry.start) + ", " + format.time(entry.start) + " – " + format.time(entry.end)
        subtitle = FocusText.kind(entry.kind) + (entry.status == .completed ? "" : " · " + FocusText.status(entry.status))
        duration = DateFormatting.duration(minutes: entry.durationMinutes)
        kind = entry.kind
        isCancelled = entry.status == .cancelled
    }
}
