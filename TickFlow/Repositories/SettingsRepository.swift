import Foundation
import Observation

/// Доступ к настройкам. `settings` наблюдаем: экраны обновятся после изменения.
@MainActor
protocol SettingsRepository: AnyObject {
    var settings: AppSettings { get }
    func update(_ change: (inout AppSettings) -> Void)
}

/// Настройки в UserDefaults одним JSON-значением.
@MainActor
@Observable
final class UserDefaultsSettingsRepository: SettingsRepository {
    private(set) var settings: AppSettings

    @ObservationIgnored private let defaults: UserDefaults
    private static let key = "appSettings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let stored = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = stored
        } else {
            settings = AppSettings()
        }
    }

    func update(_ change: (inout AppSettings) -> Void) {
        var copy = settings
        change(&copy)
        guard copy != settings else { return }
        settings = copy
        if let data = try? JSONEncoder().encode(copy) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
