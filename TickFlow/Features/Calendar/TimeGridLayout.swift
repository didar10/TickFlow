import CoreGraphics
import Foundation

/// Размеры шкалы. Нужны и View (рисовать), и ViewModel (переводить смещение пальца в минуты).
struct TimelineGeometry: Equatable {
    let hourHeight: CGFloat
    let gutterWidth: CGFloat = 46
    let dayCount: Int

    init(mode: CalendarMode) {
        hourHeight = mode == .day ? 64 : 52
        dayCount = max(1, mode.dayCount)
    }

    var isNarrow: Bool { dayCount == 7 }

    /// Ширина полосы учтённого времени у правого края колонки: подписи есть только в «Дне».
    var sessionLaneWidth: CGFloat {
        switch dayCount {
        case 1: 78
        case 3: 12
        default: 6
        }
    }

    var showsSessionLabels: Bool { dayCount == 1 }
    var contentHeight: CGFloat { hourHeight * 24 }

    func y(forMinute minute: Int) -> CGFloat {
        CGFloat(minute) / 60 * hourHeight
    }

    func height(minutes: Int) -> CGFloat {
        CGFloat(minutes) / 60 * hourHeight
    }

    /// Смещение по вертикали → минуты с шагом 15.
    func snappedMinutes(forDelta dy: CGFloat) -> Int {
        Int((dy / hourHeight * 4).rounded()) * 15
    }

    /// Минута начала для нажатия на свободное место: вниз до получаса.
    func slotMinute(atY y: CGFloat) -> Int {
        let minute = Int(y / hourHeight * 60) / 30 * 30
        return min(max(minute, 0), 1410)
    }
}

/// Раскладка задач дня: пересекающиеся стоят рядом, а не друг на друге.
enum TimeGridLayout {
    struct Item {
        let id: UUID
        let start: Int
        let end: Int
    }

    struct Placement: Equatable {
        let lane: Int
        let laneCount: Int
    }

    /// Группирует пересекающиеся задачи и раздаёт им дорожки. Как в макете:
    /// по началу, при равном начале — более длинная первой.
    static func place(_ items: [Item]) -> [UUID: Placement] {
        let sorted = items.sorted { ($0.start, -$0.end) < ($1.start, -$1.end) }
        var result: [UUID: Placement] = [:]
        var cluster: [(Item, Int)] = []
        var laneEnds: [Int] = []
        var clusterEnd = -1

        func flush() {
            for (item, lane) in cluster {
                result[item.id] = Placement(lane: lane, laneCount: laneEnds.count)
            }
            cluster = []
            laneEnds = []
        }

        for item in sorted {
            if !cluster.isEmpty, item.start >= clusterEnd {
                flush()
                clusterEnd = -1
            }
            let lane: Int
            if let free = laneEnds.firstIndex(where: { $0 <= item.start }) {
                lane = free
                laneEnds[free] = item.end
            } else {
                lane = laneEnds.count
                laneEnds.append(item.end)
            }
            cluster.append((item, lane))
            clusterEnd = max(clusterEnd, item.end)
        }
        flush()
        return result
    }

    struct Bar {
        let id: UUID
        /// Индексы видимых дней, на которые попадает полоса.
        let first: Int
        let last: Int
    }

    /// Дорожки строки «весь день»: полосы не перекрываются.
    static func lanes(for bars: [Bar]) -> (lanes: [UUID: Int], count: Int) {
        var laneEnds: [Int] = []
        var result: [UUID: Int] = [:]
        for bar in bars {
            if let free = laneEnds.firstIndex(where: { $0 < bar.first }) {
                laneEnds[free] = bar.last
                result[bar.id] = free
            } else {
                result[bar.id] = laneEnds.count
                laneEnds.append(bar.last)
            }
        }
        return (result, laneEnds.count)
    }
}
