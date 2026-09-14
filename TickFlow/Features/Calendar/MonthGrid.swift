import SwiftUI

/// Сетка месяца. Дни за пределами месяца приглушены, под числом — индикатор задач.
struct MonthGrid: View {
    let month: Date
    @Binding var selectedDate: Date
    /// Количество незавершённых задач по дням (ключ — начало дня).
    let taskCounts: [Date: Int]

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol.uppercased())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(days, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)
        let inMonth = calendar.isDate(day, equalTo: month, toGranularity: .month)
        let count = taskCounts[calendar.startOfDay(for: day)] ?? 0

        VStack(spacing: 3) {
            Text(day.formatted(.dateTime.day()))
                .font(.callout)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(foreground(isSelected: isSelected, isToday: isToday, inMonth: inMonth))

            Circle()
                .fill(count > 0 ? Color.accentColor : Color.clear)
                .frame(width: 5, height: 5)
                .opacity(inMonth ? 1 : 0.4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.18))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDate = calendar.startOfDay(for: day)
        }
    }

    private func foreground(isSelected: Bool, isToday: Bool, inMonth: Bool) -> Color {
        if isToday { return .accentColor }
        if !inMonth { return .secondary.opacity(0.5) }
        return .primary
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        guard shift > 0, shift < symbols.count else { return symbols }
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private var days: [Date] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: month),
            let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
            let lastWeek = calendar.dateInterval(
                of: .weekOfMonth,
                for: monthInterval.end.addingTimeInterval(-1)
            )
        else { return [] }

        var result: [Date] = []
        var current = firstWeek.start
        while current < lastWeek.end {
            result.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return result
    }
}
