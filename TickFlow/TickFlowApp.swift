import SwiftData
import SwiftUI

@main
struct TickFlowApp: App {
    @State private var dependencies: AppDependencies

    init() {
        do {
            let container = try ModelContainer(for: TaskList.self, TaskItem.self, Subtask.self)
            _dependencies = State(initialValue: AppDependencies(container: container))
        } catch {
            fatalError("Не удалось создать ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                .environment(dependencies)
        }
    }
}
