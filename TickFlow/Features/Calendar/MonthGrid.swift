import SwiftUI

/// Сетка месяца: до трёх точек задач под числом и легенда.
struct MonthGrid: View {
    let viewModel: CalendarViewModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(Array(viewModel.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(viewModel.monthCells) { cell in
                    MonthCellView(cell: cell) { viewModel.select(cell.id) }
                }
            }

            HStack(spacing: 14) {
                legend(AppColors.accent, L10n.Common.planned)
                legend(AppColors.nowLine, L10n.Common.overdue)
                legend(AppColors.doneDot, L10n.Common.completed)
                HStack(spacing: 5) {
                    DiagonalStripes(spacing: 3.5, lineWidth: 1.5)
                        .fill(AppColors.accent)
                        .frame(width: 10, height: 6)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    Text(L10n.Calendar.trackedLegend).font(.system(size: 11)).foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.surface)
        .contentShape(Rectangle())
        // Свайп влево/вправо по сетке листает месяцы; вертикальная прокрутка не мешает.
        .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded {
            viewModel.swipe(dx: $0.translation.width, dy: $0.translation.height)
        })
    }

    private func legend(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title).font(.system(size: 11)).foregroundStyle(AppColors.textSecondary)
        }
    }
}

private struct MonthCellView: View {
    let cell: CalendarItems.MonthCell
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(cell.number)
                    .font(.system(size: 16, weight: cell.isSelected || cell.isToday ? .semibold : .regular))
                    .foregroundStyle(numberColor)
                    .frame(width: 32, height: 32)
                    .background {
                        if cell.isSelected {
                            Circle().fill(cell.isToday ? AppColors.accent : AppColors.inverse)
                        }
                    }
                HStack(spacing: 2) {
                    ForEach(Array(cell.dotHexes.enumerated()), id: \.offset) { _, hex in
                        Circle().fill(Color(hex: hex)).frame(width: 5, height: 5)
                    }
                    if !cell.more.isEmpty {
                        Text(cell.more)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
                .frame(height: 6)
                .opacity(cell.isInMonth ? 1 : 0.4)
                Text(cell.tracked)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(height: 11)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var numberColor: Color {
        if cell.isSelected { return .white }
        if cell.isToday { return AppColors.accent }
        if !cell.isInMonth { return AppColors.chevron }
        return AppColors.label
    }
}
