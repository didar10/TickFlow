import Foundation

/// Раздел «Учтённое время» в аналитике.
struct TimeReport {
    struct Kpi: Identifiable {
        var id: String { title }
        let title: String
        let value: String
        let detail: String
    }

    struct Bar: Identifiable {
        let id: Int
        let label: String
        let minutes: Int
        let isCurrent: Bool
    }

    struct CategoryRow: Identifiable {
        let id: String
        let name: String
        let minutes: Int
        let value: String
        /// Нет — серая полоса «Без задачи».
        let colorHex: String?
    }

    struct TaskRow: Identifiable {
        let id: UUID
        let title: String
        let actual: Int
        let estimate: Int?
        let value: String
        var isOver: Bool { estimate.map { actual > $0 } ?? false }
    }

    let kpis: [Kpi]
    let trendTitle: String
    let trendAverage: String
    let bars: [Bar]
    let maxBar: Int
    let focusMinutes: Int
    let breakMinutes: Int
    let categories: [CategoryRow]
    let tasks: [TaskRow]
    /// Масштаб полос «Оценка и факт»: самое большое из оценок и факта.
    let taskScale: Int

    var focusShare: Double {
        let total = focusMinutes + breakMinutes
        return total > 0 ? Double(focusMinutes) / Double(total) : 0
    }

    var maxCategory: Int { max(1, categories.map(\.minutes).max() ?? 1) }
}

extension InsightsViewModel {
    /// Учёт времени показывается, когда есть хотя бы одна запись.
    var hasTimeData: Bool { !(timeEntries?.entries.isEmpty ?? true) }

    var timeReport: TimeReport {
        let format = DisplayFormatter(settings: settings.settings, clock: clock)
        let calendar = format.calendar
        let today = format.today
        let interval = period(for: range, offset: 0, today: today, calendar: calendar)
        let all = timeEntries?.entries ?? []
        let inRange = all.filter { interval.start <= $0.start && $0.start < interval.end }
        let work = inRange.filter(\.countsAsWork)
        let focus = inRange.filter { $0.kind == .focus }
        let breaks = inRange.filter { $0.kind == .breakTime && $0.status != .cancelled }
        let minutes = { (entries: [TimeEntry]) in entries.reduce(0) { $0 + $1.durationMinutes } }
        let duration = { (value: Int) in DateFormatting.duration(minutes: value) }

        let todayWork = all.filter { $0.countsAsWork && calendar.isDate($0.start, inSameDayAs: today) }
        let total = minutes(work)
        let elapsedEnd = min(interval.end, calendar.date(byAdding: .day, value: 1, to: today) ?? today)
        let days = max(1, calendar.dateComponents([.day], from: interval.start, to: elapsedEnd).day ?? 1)
        let completed = focus.filter { $0.status == .completed }.count
        let lengths = work.map(\.durationMinutes)

        let periodTitle = switch range {
        case .week: L10n.Focus.timePeriodWeek
        case .month: L10n.Focus.timePeriodMonth
        case .year: L10n.Focus.timePeriodYear
        }
        let kpis = [
            TimeReport.Kpi(title: L10n.Common.today, value: duration(minutes(todayWork)), detail: L10n.Focus.sessions(todayWork.count)),
            TimeReport.Kpi(title: periodTitle, value: duration(total),
                           detail: L10n.Focus.dailyAverage(duration(Int((Double(total) / Double(days)).rounded())))),
            TimeReport.Kpi(title: L10n.Focus.focusSessions, value: String(completed),
                           detail: L10n.Focus.completedShare("\(focus.isEmpty ? 0 : Int((Double(completed) / Double(focus.count) * 100).rounded()))%")),
            TimeReport.Kpi(title: L10n.Focus.averageSession,
                           value: duration(lengths.isEmpty ? 0 : Int((Double(total) / Double(lengths.count)).rounded())),
                           detail: L10n.Focus.longest(duration(lengths.max() ?? 0))),
        ]

        let ranges = bucketRanges(interval: interval, calendar: calendar, format: format)
        let bars = ranges.enumerated().map { index, item in
            TimeReport.Bar(
                id: index, label: item.label,
                minutes: minutes(work.filter { item.interval.start <= $0.start && $0.start < item.interval.end }),
                isCurrent: index == ranges.count - 1
            )
        }
        let trendTitle = switch range {
        case .week: L10n.Insights.byDay
        case .month: L10n.Insights.byWeek
        case .year: L10n.Insights.byMonth
        }
        let average = bars.isEmpty ? 0 : bars.reduce(0) { $0 + $1.minutes } / bars.count

        var byCategory: [String: (name: String, minutes: Int, color: String?)] = [:]
        for entry in work {
            let key: String, name: String, color: String?
            if let task = entry.task {
                key = task.list?.id.uuidString ?? "none"
                name = task.list?.name ?? L10n.Common.noCategory
                color = task.list?.colorHex ?? AppColors.fallbackList
            } else {
                key = "task"
                name = L10n.Focus.noTask
                color = nil
            }
            byCategory[key, default: (name, 0, color)].minutes += entry.durationMinutes
        }
        let categories = byCategory
            .map { TimeReport.CategoryRow(id: $0.key, name: $0.value.name, minutes: $0.value.minutes,
                                          value: duration($0.value.minutes), colorHex: $0.value.color) }
            .sorted { ($0.minutes, $1.name) > ($1.minutes, $0.name) }

        var byTask: [UUID: (task: TaskItem, minutes: Int)] = [:]
        for entry in work {
            guard let task = entry.task else { continue }
            byTask[task.id, default: (task, 0)].minutes += entry.durationMinutes
        }
        let tasks = byTask.values
            .sorted { ($0.minutes, $1.task.title) > ($1.minutes, $0.task.title) }
            .prefix(5)
            .map { item in
                let estimate = item.task.effectiveEstimate
                return TimeReport.TaskRow(
                    id: item.task.id, title: item.task.title, actual: item.minutes, estimate: estimate,
                    value: estimate.map { duration(item.minutes) + " / " + duration($0) } ?? L10n.Focus.withoutEstimate(duration(item.minutes))
                )
            }

        return TimeReport(
            kpis: kpis,
            trendTitle: trendTitle,
            trendAverage: L10n.Focus.trendAverage(duration(average)),
            bars: bars,
            maxBar: max(1, bars.map(\.minutes).max() ?? 1),
            focusMinutes: total,
            breakMinutes: minutes(breaks),
            categories: categories,
            tasks: Array(tasks),
            taskScale: max(1, tasks.map { max($0.actual, $0.estimate ?? 0) }.max() ?? 1)
        )
    }
}
