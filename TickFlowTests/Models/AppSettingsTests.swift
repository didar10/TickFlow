import Foundation
import Testing
@testable import TickFlow

struct AppSettingsTests {
    private func decode(_ json: String) throws -> AppSettings {
        try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
    }

    @Test func roundTrip() throws {
        var settings = AppSettings()
        settings.firstWeekday = 1
        settings.defaultCalendarMode = .day
        settings.lastCalendarMode = .month
        settings.uses24HourTime = false
        settings.defaultTaskDuration = 45
        settings.theme = .dark
        settings.taskRemindersEnabled = false
        settings.defaultReminder = .hourBefore
        settings.habitRemindersEnabled = false
        settings.allowsRestDays = false
        settings.skippedDaysKeepStreak = false
        settings.workdayStartHour = 8
        settings.workdayEndHour = 20
        settings.hasCompletedOnboarding = true

        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(AppSettings.self, from: data) == settings)
    }

    @Test func emptyJSONGivesDefaults() throws {
        #expect(try decode("{}") == AppSettings())
    }

    @Test func oldJSONWithoutNewKeysKeepsStoredValues() throws {
        let settings = try decode(#"{"firstWeekday": 1, "uses24HourTime": false}"#)
        var expected = AppSettings()
        expected.firstWeekday = 1
        expected.uses24HourTime = false
        #expect(settings == expected)
        #expect(settings.lastCalendarMode == nil)
    }

    @Test func unknownKeysAreIgnored() throws {
        let settings = try decode(#"{"removedOption": true, "defaultTaskDuration": 30}"#)
        #expect(settings.defaultTaskDuration == 30)
    }

    /// Ключ с неверным типом ломает декодирование целиком — репозиторий тогда берёт настройки по умолчанию.
    @Test func wrongTypeThrows() {
        #expect(throws: DecodingError.self) { try decode(#"{"firstWeekday": "monday"}"#) }
        #expect(throws: DecodingError.self) { try decode(#"{"theme": 42}"#) }
    }

    @Test func defaults() {
        let settings = AppSettings()
        #expect(settings.firstWeekday == 2)
        #expect(settings.defaultCalendarMode == .week)
        #expect(settings.uses24HourTime)
        #expect(settings.defaultTaskDuration == 60)
        #expect(settings.defaultReminder == .tenMinutesBefore)
        #expect(!settings.hasCompletedOnboarding)
    }
}
