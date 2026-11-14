import SwiftData
import SwiftUI

@main
struct TickFlowApp: App {
    /// `nil` под юнит-тестами: приложение-хост не открывает базу, не трогает UserDefaults и уведомления.
    @State private var dependencies: AppDependencies?

    init() {
        guard !LaunchEnvironment.isRunningUnitTests else { return }
        do {
            let container = try ModelContainer(for: Schema(AppDependencies.modelTypes))
            _dependencies = State(initialValue: AppDependencies(container: container))
        } catch {
            fatalError("Не удалось создать ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            if let dependencies {
                RootView(dependencies: dependencies)
                    .environment(dependencies)
                    .environment(dependencies.focus)
            }
        }
    }
}

enum LaunchEnvironment {
    /// Приложение запущено как хост тестового бандла.
    static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }
}
