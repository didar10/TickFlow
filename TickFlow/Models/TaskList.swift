import Foundation
import SwiftData

@Model
final class TaskList {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#3B82F6"
    var symbolName: String = "list.bullet"
    var sortOrder: Int = 0
    var createdAt: Date = Date.now
    /// Задачи категории по умолчанию показывают таймер, фокус и потраченное время.
    var tracksTimeByDefault: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.list)
    var tasks: [TaskItem] = []

    init(
        name: String,
        colorHex: String = "#3B82F6",
        symbolName: String = "list.bullet",
        sortOrder: Int = 0,
        tracksTimeByDefault: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.symbolName = symbolName
        self.sortOrder = sortOrder
        self.tracksTimeByDefault = tracksTimeByDefault
        self.createdAt = .now
    }

    /// Сколько задач категории переопределяют её настройку трекинга.
    var trackingOverrideCount: Int {
        tasks.filter { $0.trackingOverride != nil && $0.trackingOverride != tracksTimeByDefault }.count
    }

    var activeCount: Int {
        tasks.filter { !$0.isCompleted }.count
    }
}
