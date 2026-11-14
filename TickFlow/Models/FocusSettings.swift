import Foundation

/// Готовые наборы длительностей таймера фокуса.
enum FocusPreset: Int, CaseIterable, Codable {
    /// 25 минут фокуса, 5 короткий перерыв, 15 длинный.
    case classic = 0
    /// 50 / 10 / 30.
    case extended = 1
    case custom = 2

    /// Длительности пресета: фокус, короткий и длинный перерыв. У `custom` своих нет.
    var durations: (focus: Int, shortBreak: Int, longBreak: Int)? {
        switch self {
        case .classic: (25, 5, 15)
        case .extended: (50, 10, 30)
        case .custom: nil
        }
    }
}

/// Настройки таймера фокуса. Значения по умолчанию совпадают с макетом.
struct FocusSettings: Codable, Equatable {
    static let focusRange = 5...120
    static let shortBreakRange = 1...30
    static let longBreakRange = 5...60
    static let longBreakEveryRange = 2...8

    var preset: FocusPreset = .classic
    var focusMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    /// Длинный перерыв после каждой N-й сессии.
    var longBreakEvery = 4
    var autoStartBreaks = true
    var autoStartFocus = false
    var sessionNotifications = true

    init() {}

    /// Выбор пресета подставляет его длительности; `custom` оставляет текущие.
    mutating func apply(_ preset: FocusPreset) {
        self.preset = preset
        guard let durations = preset.durations else { return }
        focusMinutes = durations.focus
        shortBreakMinutes = durations.shortBreak
        longBreakMinutes = durations.longBreak
    }

    /// Новые поля не ломают старые сохранения: отсутствующие ключи берутся по умолчанию.
    init(from decoder: Decoder) throws {
        let defaults = FocusSettings()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        preset = try c.decodeIfPresent(FocusPreset.self, forKey: .preset) ?? defaults.preset
        focusMinutes = try c.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? defaults.focusMinutes
        shortBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .shortBreakMinutes) ?? defaults.shortBreakMinutes
        longBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? defaults.longBreakMinutes
        longBreakEvery = try c.decodeIfPresent(Int.self, forKey: .longBreakEvery) ?? defaults.longBreakEvery
        autoStartBreaks = try c.decodeIfPresent(Bool.self, forKey: .autoStartBreaks) ?? defaults.autoStartBreaks
        autoStartFocus = try c.decodeIfPresent(Bool.self, forKey: .autoStartFocus) ?? defaults.autoStartFocus
        sessionNotifications = try c.decodeIfPresent(Bool.self, forKey: .sessionNotifications) ?? defaults.sessionNotifications
    }
}
