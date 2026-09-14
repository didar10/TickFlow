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

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.list)
    var tasks: [TaskItem] = []

    init(
        name: String,
        colorHex: String = "#3B82F6",
        symbolName: String = "list.bullet",
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.symbolName = symbolName
        self.sortOrder = sortOrder
        self.createdAt = .now
    }

    var activeCount: Int {
        tasks.filter { !$0.isCompleted }.count
    }
}
