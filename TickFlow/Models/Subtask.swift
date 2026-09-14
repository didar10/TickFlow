import Foundation
import SwiftData

@Model
final class Subtask {
    var id: UUID = UUID()
    var title: String = ""
    var isCompleted: Bool = false
    var sortOrder: Int = 0
    var parent: TaskItem?

    init(title: String, isCompleted: Bool = false, sortOrder: Int = 0) {
        self.id = UUID()
        self.title = title
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
    }
}
