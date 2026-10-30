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

/// Цвета интерфейса. Акцент задан в ассете AccentColor.
enum AppColors {
    static let background = Color(light: "#F4F5F7", dark: "#0E1211")
    static let surface = Color(light: "#FFFFFF", dark: "#1A1F1E")
    static let hairline = Color(light: "#E4E6EA", dark: "#2A302F")
    static let fallbackList = "#3FA796"

    static func listColor(_ list: TaskList?) -> Color {
        Color(hex: list?.colorHex ?? fallbackList)
    }
}

extension View {
    /// Единый фон экрана для списков и форм.
    func screenBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(AppColors.background.ignoresSafeArea())
    }
}

enum AppPalette {
    /// Палитра для пользовательских списков.
    static let listColors: [String] = [
        "#3B82F6", "#22C55E", "#F97316", "#EF4444",
        "#A855F7", "#14B8A6", "#EAB308", "#EC4899"
    ]

    static let listSymbols: [String] = [
        "list.bullet", "tray", "briefcase", "house",
        "cart", "book", "heart", "airplane", "dumbbell", "graduationcap"
    ]
}

enum DateFormatting {

    static func dueLabel(for date: Date, hasTime: Bool, calendar: Calendar = .current) -> String {
        let day: String
        if calendar.isDateInToday(date) {
            day = "Сегодня"
        } else if calendar.isDateInTomorrow(date) {
            day = "Завтра"
        } else if calendar.isDateInYesterday(date) {
            day = "Вчера"
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
        guard task.hasTime, let due = task.dueDate else { return "Весь\nдень" }
        return time(for: due)
    }

    static func monthTitle(for date: Date) -> String {
        let isCurrentYear = Calendar.current.isDate(date, equalTo: .now, toGranularity: .year)
        let style = isCurrentYear ? Date.FormatStyle().month(.wide) : Date.FormatStyle().month(.wide).year()
        return date.formatted(style).capitalized
    }
}
