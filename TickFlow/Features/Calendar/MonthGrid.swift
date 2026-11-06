import SwiftUI

/// Сетка месяца. Дни за пределами месяца приглушены, под числом — индикатор задач.
struct MonthGrid: View {
    let month: Date
    let days: [Date]
    let weekdaySymbols: [String]
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

        VStack(spacing: 2) {
            Text(day.formatted(.dateTime.day()))
                .font(.callout)
                .fontWeight(isSelected || isToday ? .semibold : .regular)
                .foregroundStyle(foreground(isSelected: isSelected, isToday: isToday, inMonth: inMonth))
                .frame(width: 32, height: 32)
                .background {
                    if isSelected {
                        Circle().fill(Color.accentColor)
                    }
                }

            Circle()
                .fill(count > 0 ? Color.accentColor : Color.clear)
                .frame(width: 5, height: 5)
                .opacity(inMonth ? 1 : 0.4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDate = calendar.startOfDay(for: day)
        }
    }

    private func foreground(isSelected: Bool, isToday: Bool, inMonth: Bool) -> Color {
        if isSelected { return .white }
        if isToday { return .accentColor }
        if !inMonth { return .secondary.opacity(0.5) }
        return .primary
    }
}
