import Foundation
import SwiftData
@testable import TickFlow

/// База в памяти со всеми моделями приложения. Каждый вызов — новая пустая база.
@MainActor
func makeInMemoryContainer() throws -> ModelContainer {
    try ModelContainer(
        for: Schema(AppDependencies.modelTypes),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}

/// Отдельный UserDefaults на тест, чтобы не трогать настройки приложения-хоста.
func makeIsolatedDefaults() -> UserDefaults {
    let suite = "TickFlowTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}
