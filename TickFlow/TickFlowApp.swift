import SwiftData
import SwiftUI

@main
struct TickFlowApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: TaskList.self, TaskItem.self, Subtask.self)
        } catch {
            fatalError("Не удалось создать ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
