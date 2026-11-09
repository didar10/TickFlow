import Foundation
import Testing
@testable import TickFlow

@MainActor
struct UserDefaultsSettingsRepositoryTests {
    let defaults = makeIsolatedDefaults()
    let key = "appSettings"

    @Test func emptyStorageGivesDefaults() {
        #expect(UserDefaultsSettingsRepository(defaults: defaults).settings == AppSettings())
    }

    @Test func updatePersistsForNextInstance() {
        let repository = UserDefaultsSettingsRepository(defaults: defaults)
        repository.update {
            $0.theme = .dark
            $0.firstWeekday = 1
            $0.lastCalendarMode = .day
        }
        #expect(repository.settings.theme == .dark)

        let reopened = UserDefaultsSettingsRepository(defaults: defaults)
        #expect(reopened.settings.theme == .dark)
        #expect(reopened.settings.firstWeekday == 1)
        #expect(reopened.settings.lastCalendarMode == .day)
    }

    @Test func unchangedUpdateDoesNotWrite() {
        let repository = UserDefaultsSettingsRepository(defaults: defaults)
        repository.update { $0.theme = AppSettings().theme }
        #expect(defaults.data(forKey: key) == nil)
    }

    @Test func corruptedDataFallsBackToDefaults() {
        defaults.set(Data("не JSON".utf8), forKey: key)
        #expect(UserDefaultsSettingsRepository(defaults: defaults).settings == AppSettings())

        defaults.set(Data(#"{"firstWeekday": "monday"}"#.utf8), forKey: key)
        #expect(UserDefaultsSettingsRepository(defaults: defaults).settings == AppSettings())
    }

    @Test func oldStoredSettingsAreMigrated() {
        defaults.set(Data(#"{"uses24HourTime": false}"#.utf8), forKey: key)
        let settings = UserDefaultsSettingsRepository(defaults: defaults).settings
        #expect(!settings.uses24HourTime)
        #expect(settings.defaultTaskDuration == AppSettings().defaultTaskDuration)
    }
}
