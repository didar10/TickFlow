import SwiftData
import SwiftUI

@main
struct TickFlowApp: App {
    @State private var dependencies: AppDependencies

    init() {
        do {
            let container = try ModelContainer(for: Schema(AppDependencies.modelTypes))
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
