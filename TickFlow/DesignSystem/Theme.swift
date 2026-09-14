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

    static func monthTitle(for date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year()).capitalized
    }
}
