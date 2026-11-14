import Foundation

/// Готовые данные для отрисовки календаря. View только размещает и красит их.
enum CalendarItems {

    struct DayHeader: Identifiable {
        let id: Date
        let weekday: String
        let number: String
        let isToday: Bool
        let isSelected: Bool
        /// Точка под числом в полосе дней.
        let hasTasks: Bool
    }

    struct HourLabel: Identifiable {
        var id: Int { hour }
        let hour: Int
        /// Пусто у полуночи и рядом с линией «сейчас».
        let text: String
    }

    struct Card: Identifiable {
        let id: UUID
        let title: String
        let time: String
        let dayIndex: Int
        let startMinute: Int
        let endMinute: Int
        let lane: Int
        let laneCount: Int
        let colorHex: String
        let isCompleted: Bool
        let isDragging: Bool
        let isHighlighted: Bool
        let hasConflict: Bool
    }

    struct Ghost: Identifiable {
        let id: UUID
        let dayIndex: Int
        let startMinute: Int
        let endMinute: Int
        let colorHex: String
    }

    struct Bar: Identifiable {
        let id: UUID
        let title: String
        let first: Int
        let last: Int
        let lane: Int
        let colorHex: String
        let isCompleted: Bool
        let isMultiDay: Bool
        let isDragging: Bool
    }

    struct NowLine {
        let dayIndex: Int
        let minute: Int
        let label: String
    }

    struct MonthCell: Identifiable {
        let id: Date
        let number: String
        let isInMonth: Bool
        let isToday: Bool
        let isSelected: Bool
        /// До трёх точек: цвет категории, красный для просроченного, серый для выполненного.
        let dotHexes: [String]
        let more: String
        /// Учтённое за день: «1ч10мин» или пусто.
        let tracked: String
    }

    /// Запись учёта времени в колонке дня: полоса справа от задач.
    struct Session: Identifiable, Equatable {
        let id: UUID
        let dayIndex: Int
        let startMinute: Int
        let endMinute: Int
        let title: String
        /// «Фокус · 25 мин · остановлена».
        let detail: String
        let colorHex: String
        let isInterrupted: Bool
    }

    struct AgendaRow: Identifiable {
        let id: UUID
        let title: String
        let time: String
        let colorHex: String
        let isCompleted: Bool
        let isUrgent: Bool
    }
}
