import Foundation
import Observation

/// Лист «Таймер фокуса»: пресет, длительности, автозапуск и уведомления.
@MainActor
@Observable
final class FocusSettingsViewModel {
    @ObservationIgnored private let settings: any SettingsRepository
    @ObservationIgnored private let focus: FocusEngine?

    init(settings: any SettingsRepository, focus: FocusEngine?) {
        self.settings = settings
        self.focus = focus
    }

    private var current: FocusSettings { settings.settings.focus }

    var preset: FocusPreset {
        get { current.preset }
        set { update { $0.apply(newValue) } }
    }

    var presets: [(value: FocusPreset, title: String)] {
        FocusPreset.allCases.map { ($0, Self.title(of: $0)) }
    }

    static func title(of preset: FocusPreset) -> String {
        switch preset {
        case .classic: "25/5"
        case .extended: "50/10"
        case .custom: L10n.Focus.presetCustom
        }
    }

    /// Значение строки в профиле: «25/5» или «40/7 мин» для своего.
    static func summary(_ settings: FocusSettings) -> String {
        guard settings.preset == .custom else { return title(of: settings.preset) }
        return "\(settings.focusMinutes)/\(settings.shortBreakMinutes) " + L10n.Format.minutesUnit
    }

    var focusText: String { L10n.Format.minutes(current.focusMinutes) }
    var shortBreakText: String { L10n.Format.minutes(current.shortBreakMinutes) }
    var longBreakText: String { L10n.Format.minutes(current.longBreakMinutes) }
    var longBreakEveryText: String { L10n.Focus.sessions(current.longBreakEvery) }

    /// Ручная правка длительности делает пресет своим.
    func stepFocus(_ delta: Int) { custom { $0.focusMinutes = clamp($0.focusMinutes + delta * 5, FocusSettings.focusRange) } }
    func stepShortBreak(_ delta: Int) { custom { $0.shortBreakMinutes = clamp($0.shortBreakMinutes + delta, FocusSettings.shortBreakRange) } }
    func stepLongBreak(_ delta: Int) { custom { $0.longBreakMinutes = clamp($0.longBreakMinutes + delta * 5, FocusSettings.longBreakRange) } }

    func stepLongBreakEvery(_ delta: Int) {
        update { $0.longBreakEvery = clamp($0.longBreakEvery + delta, FocusSettings.longBreakEveryRange) }
    }

    var autoStartBreaks: Bool {
        get { current.autoStartBreaks }
        set { update { $0.autoStartBreaks = newValue } }
    }

    var autoStartFocus: Bool {
        get { current.autoStartFocus }
        set { update { $0.autoStartFocus = newValue } }
    }

    var sessionNotifications: Bool {
        get { current.sessionNotifications }
        set { update { $0.sessionNotifications = newValue } }
    }

    private func custom(_ change: (inout FocusSettings) -> Void) {
        update {
            change(&$0)
            $0.preset = .custom
        }
    }

    private func update(_ change: (inout FocusSettings) -> Void) {
        settings.update { change(&$0.focus) }
        focus?.settingsChanged()
    }

    private func clamp(_ value: Int, _ range: ClosedRange<Int>) -> Int {
        min(range.upperBound, max(range.lowerBound, value))
    }
}
