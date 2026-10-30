import Foundation

/// Задача, размещённая в колонке дня.
struct PlacedTask: Identifiable {
    let task: TaskItem
    let startMinute: Int
    let endMinute: Int
    var column: Int
    var columnCount: Int

    var id: UUID { task.id }
}

/// Раскладывает задачи дня так, чтобы пересекающиеся стояли рядом, а не друг на друге.
enum TimeGridLayout {
    static let minutesInDay = 24 * 60
    /// Короткая задача занимает не меньше этого времени, иначе её блок не прочитать.
    static let minimumVisualMinutes = 25

    static func place(_ tasks: [TaskItem], calendar: Calendar = .current) -> [PlacedTask] {
        let items: [PlacedTask] = tasks.compactMap { task in
            guard let due = task.dueDate else { return nil }
            let parts = calendar.dateComponents([.hour, .minute], from: due)
            let start = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            let duration = max(task.durationMinutes, minimumVisualMinutes)
            // Задача через полночь обрезается концом дня.
            let end = min(start + duration, minutesInDay)
            return PlacedTask(task: task, startMinute: start, endMinute: end, column: 0, columnCount: 1)
        }
        .sorted { ($0.startMinute, $1.endMinute) < ($1.startMinute, $0.endMinute) }

        var result: [PlacedTask] = []
        var cluster: [PlacedTask] = []
        var columnEnds: [Int] = []
        var clusterEnd = 0

        func flushCluster() {
            result += cluster.map { placed in
                var placed = placed
                placed.columnCount = columnEnds.count
                return placed
            }
            cluster = []
            columnEnds = []
        }

        for var item in items {
            if item.startMinute >= clusterEnd {
                flushCluster()
                clusterEnd = 0
            }
            if let free = columnEnds.firstIndex(where: { $0 <= item.startMinute }) {
                item.column = free
                columnEnds[free] = item.endMinute
            } else {
                item.column = columnEnds.count
                columnEnds.append(item.endMinute)
            }
            cluster.append(item)
            clusterEnd = max(clusterEnd, item.endMinute)
        }
        flushCluster()
        return result
    }
}
