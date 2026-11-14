import SwiftUI

extension Color {
    /// Цвет из HEX-строки вида "#RRGGBB". При ошибке возвращает системный accent.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        guard cleaned.count == 6, Scanner(string: cleaned).scanHexInt64(&value) else {
            self = .accentColor
            return
        }
        self = Color(
            red: Double((value & 0xFF0000) >> 16) / 255,
            green: Double((value & 0x00FF00) >> 8) / 255,
            blue: Double(value & 0x0000FF) / 255
        )
    }
}

extension Color {
    /// Цвет, зависящий от светлой или тёмной темы.
    init(light: String, dark: String) {
        let lightColor = UIColor(Color(hex: light))
        let darkColor = UIColor(Color(hex: dark))
        self = Color(UIColor { $0.userInterfaceStyle == .dark ? darkColor : lightColor })
    }
}

/// Цвета интерфейса Cadence. Светлые и тёмные значения — из токенов макета.
enum AppColors {
    /// Акцент одинаковый в обеих темах; в тёмной чуть светлее для читаемости текста.
    static let accent = Color(light: "#5B5BD6", dark: "#7B7BEA")
    static let accentPressed = Color(light: "#3A39AE", dark: "#B4B3FF")
    static let accentSoft = Color(light: "#EDEDFC", dark: "#26264A")
    static let accentMuted = Color(light: "#DADAF5", dark: "#3A3A6A")
    static let accentFaded = Color(light: "#C4C3F2", dark: "#4A4A80")
    static let avatar = Color(light: "#E8E8F7", dark: "#2A2A50")

    /// Фон сгруппированных экранов (Задачи, Привычки, Профиль).
    static let background = Color(light: "#F2F2F7", dark: "#000000")
    /// Фон экрана календаря, карточек и листов.
    static let surface = Color(light: "#FFFFFF", dark: "#1C1C1E")
    /// Заливка полей поиска, сегментов и неактивных чипов.
    static let fill = Color(light: "#E6E6EB", dark: "#2C2C2E")
    static let fillSecondary = Color(light: "#F2F2F7", dark: "#2C2C2E")
    /// Круглые кнопки в шапке (вид календаря).
    static let fillTertiary = Color(light: "#EEEEF0", dark: "#2C2C2E")
    /// Утопленные блоки внутри карточек.
    static let insetFill = Color(light: "#F7F7F9", dark: "#2C2C2E")
    /// Карточка выполненной задачи в календаре.
    static let completedFill = Color(light: "#F4F4F6", dark: "#2C2C2E")
    static let completedText = Color(light: "#9A9AA0", dark: "#8E8E93")
    static let track = Color(light: "#EFEFF3", dark: "#2C2C2E")
    /// Тёмная заливка выбранного чипа или дня (в тёмной теме — серая).
    static let inverse = Color(light: "#1C1C1E", dark: "#3A3A3C")

    static let label = Color(light: "#1C1C1E", dark: "#F2F2F7")
    static let labelSecondary = Color(light: "#3A3A3C", dark: "#D1D1D6")
    static let textSecondary = Color(light: "#6C6C70", dark: "#A1A1A8")
    static let textTertiary = Color(light: "#8E8E93", dark: "#8E8E93")
    static let textQuaternary = Color(light: "#AEAEB2", dark: "#6C6C70")
    static let chevron = Color(light: "#C7C7CC", dark: "#545458")
    static let disabled = Color(light: "#D1D1D6", dark: "#48484A")

    static let hairline = Color(light: "#EFEFF2", dark: "#2C2C2E")
    static let separator = Color(light: "#E5E5EA", dark: "#38383A")
    /// Контуры пропущенных дней и неактивных точек.
    static let outline = Color(light: "#E0E0E5", dark: "#38383A")
    static let chartLine = Color(light: "#E2E2E8", dark: "#38383A")

    static let danger = Color(light: "#D93D42", dark: "#FF6B6F")
    static let dangerSoft = Color(light: "#FDECEC", dark: "#3A1D1F")
    static let dangerText = Color(light: "#B4262B", dark: "#FF9A9D")
    static let nowLine = Color(light: "#E5484D", dark: "#FF6B6F")
    static let warning = Color(light: "#CF8526", dark: "#CF8526")
    static let warningSoft = Color(light: "#FBEFDE", dark: "#3A2C18")
    static let warningText = Color(light: "#8D550C", dark: "#F0B35E")
    static let success = Color(light: "#24713F", dark: "#7AD69A")
    /// Перерыв в фокусе: кольцо, кнопка и живая плашка.
    static let breakTint = Color(light: "#399E62", dark: "#4CB878")
    static let breakSoft = Color(light: "#E4F3EA", dark: "#173222")
    /// Кольцо мини-плеера на тёмном фоне.
    static let focusRingOnDark = Color(hex: "#A9A8FF")
    static let breakRingOnDark = Color(hex: "#7BD88F")
    static let doneDot = Color(light: "#D1D1D6", dark: "#48484A")

    static let toastBackground = Color(light: "#1C1C1E", dark: "#3A3A3C")
    static let toastAction = Color(hex: "#A9A8FF")

    static let fallbackList = "#5B5BD6"

    static func listColor(_ list: TaskList?) -> Color {
        Color(hex: list?.colorHex ?? fallbackList)
    }
}

/// Тройка цветов категории: метка, фон карточки и текст на этом фоне.
struct CategoryStyle {
    let tint: Color
    let background: Color
    let foreground: Color

    /// Пары из макета для базовой палитры. Для остальных цветов фон и текст выводятся из основного.
    private static let known: [String: (bg: String, fg: String, darkBg: String, darkFg: String)] = [
        "#5B5BD6": ("#EDEDFC", "#3A39AE", "#26264A", "#B4B3FF"),
        "#2A9792": ("#E2F3F2", "#1A6764", "#14302E", "#76D6CF"),
        "#399E62": ("#E4F3EA", "#24713F", "#16301F", "#7AD69A"),
        "#CF8526": ("#FBEFDE", "#8D550C", "#3A2C18", "#F0B35E"),
        "#BE5A96": ("#F7E7F0", "#8A3967", "#3A1E30", "#F3A6D2"),
        "#6C6C70": ("#EFEFF2", "#3A3A3C", "#2C2C2E", "#D1D1D6"),
    ]

    init(hex: String) {
        let key = hex.uppercased()
        tint = Color(hex: key)
        if let pair = Self.known[key] {
            background = Color(light: pair.bg, dark: pair.darkBg)
            foreground = Color(light: pair.fg, dark: pair.darkFg)
        } else {
            background = Color(hex: key).opacity(0.16)
            foreground = Color(hex: key)
        }
    }

    init(list: TaskList?) {
        self.init(hex: list?.colorHex ?? AppColors.fallbackList)
    }
}

extension View {
    /// Единый фон экрана для списков и форм.
    func screenBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(AppColors.background.ignoresSafeArea())
    }

    /// Белая карточка со скруглением, как блоки в макете.
    func card(cornerRadius: CGFloat = 14, padding: CGFloat? = nil) -> some View {
        self
            .padding(padding ?? 0)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

enum AppFont {
    static let largeTitle = Font.system(size: 34, weight: .bold)
    static let calendarTitle = Font.system(size: 26, weight: .bold)
    static let sectionTitle = Font.system(size: 20, weight: .bold)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 16)
    static let subheadline = Font.system(size: 15)
    static let footnote = Font.system(size: 13)
    static let caption = Font.system(size: 11, weight: .medium)
}

enum AppPalette {
    /// Цвета категорий и привычек из макета.
    static let listColors: [String] = [
        "#5B5BD6", "#2A9792", "#399E62", "#CF8526", "#BE5A96", "#6C6C70"
    ]

    static let listSymbols: [String] = [
        "list.bullet", "tray", "briefcase", "house",
        "cart", "book", "heart", "airplane", "dumbbell", "graduationcap"
    ]

    /// Иконки привычек: SF Symbols, близкие к иконкам макета.
    static let habitSymbols: [String] = [
        "book", "drop", "dumbbell", "leaf", "lightbulb", "moon", "pencil", "heart"
    ]
}

enum DateFormatting {

    static func dueLabel(for date: Date, hasTime: Bool, calendar: Calendar = .current) -> String {
        let day: String
        if calendar.isDateInToday(date) {
            day = L10n.Common.today
        } else if calendar.isDateInTomorrow(date) {
            day = L10n.Common.tomorrow
        } else if calendar.isDateInYesterday(date) {
            day = L10n.Common.yesterday
        } else {
            day = date.formatted(.dateTime.day().month(.abbreviated))
        }
        guard hasTime else { return day }
        return day + ", " + date.formatted(.dateTime.hour().minute())
    }

    /// 24-часовое время независимо от локали: "07:40".
    static func time(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// "07:40 – 08:20" для задачи со временем.
    static func timeRange(for task: TaskItem) -> String? {
        guard let start = task.dueDate, let end = task.endDate else { return nil }
        return time(for: start) + " – " + time(for: end)
    }

    /// "Сегодня, 07:40 – 08:20" или "Сегодня", если времени нет.
    static func dueRangeLabel(for task: TaskItem) -> String? {
        guard let due = task.dueDate else { return nil }
        let day = dueLabel(for: due, hasTime: false)
        guard let range = timeRange(for: task) else { return day }
        return day + ", " + range
    }

    /// Подпись времени в повестке дня.
    static func agendaLabel(for task: TaskItem) -> String {
        guard task.hasTime, let due = task.dueDate else { return L10n.Common.allDayShortCapitalized }
        return time(for: due)
    }

    static func monthTitle(for date: Date) -> String {
        let isCurrentYear = Calendar.current.isDate(date, equalTo: .now, toGranularity: .year)
        let style = isCurrentYear ? Date.FormatStyle().month(.wide) : Date.FormatStyle().month(.wide).year()
        return date.formatted(style).capitalized
    }

    /// "1ч 30м", "45м".
    static func duration(minutes: Int) -> String {
        let hours = minutes / 60, rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return L10n.Format.minutes(rest)
        case (_, 0): return L10n.Format.hours(hours)
        default: return L10n.Format.hoursMinutes(hours, rest)
        }
    }
}
