import SwiftUI

struct HabitDetailView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: HabitDetailViewModel

    init(viewModel: HabitDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            VStack(spacing: 12) {
                header
                statsGrid
                MonthHistoryCard(viewModel: viewModel)
                TrendCard(bars: viewModel.trend, colorHex: viewModel.colorHex)
                infoCard

                Button(viewModel.skipTitle, action: viewModel.skipOrReset)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .buttonStyle(.plain)

                Text(viewModel.footnote)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L10n.Common.edit, action: viewModel.edit)
            }
        }
        .sheet(item: $viewModel.editorRequest) { request in
            HabitEditorView(viewModel: dependencies.makeHabitEditorViewModel(request: request))
        }
        .onChange(of: viewModel.isMissing) { _, missing in
            if missing { dismiss() }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            HabitIcon(symbol: viewModel.symbolName, colorHex: viewModel.colorHex, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.name)
                    .font(AppFont.calendarTitle)
                    .tracking(-0.4)
                    .foregroundStyle(AppColors.label)
                Text(viewModel.meta)
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(viewModel.stats) { stat in
                VStack(alignment: .leading, spacing: 2) {
                    Text(stat.title)
                        .font(AppFont.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                    Text(stat.value)
                        .font(AppFont.calendarTitle)
                        .tracking(-0.4)
                        .foregroundStyle(AppColors.label)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(stat.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var infoCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.infoRows.enumerated()), id: \.element.id) { index, row in
                HStack {
                    Text(row.title).foregroundStyle(AppColors.label)
                    Spacer()
                    Text(row.value).foregroundStyle(AppColors.textSecondary)
                }
                .font(AppFont.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                if index < viewModel.infoRows.count - 1 {
                    Divider().overlay(AppColors.separator).padding(.leading, 16)
                }
            }
        }
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct MonthHistoryCard: View {
    let viewModel: HabitDetailViewModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let tint = Color(hex: viewModel.colorHex)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(viewModel.monthTitle)
                    .font(AppFont.headline)
                    .foregroundStyle(AppColors.label)
                Spacer()
                arrow("chevron.left", enabled: true, action: viewModel.showPreviousMonth)
                arrow("chevron.right", enabled: viewModel.canShowNextMonth, action: viewModel.showNextMonth)
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(viewModel.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.textTertiary)
                }
                ForEach(viewModel.cells) { cell in
                    DayCellView(cell: cell, tint: tint)
                        .onTapGesture { viewModel.select(cell.day) }
                }
            }

            FlowLayout(spacing: 12, lineSpacing: 6) {
                legend(L10n.Common.completed) { Circle().fill(tint).frame(width: 11, height: 11) }
                legend(L10n.Common.skipped) { SkipCircle().frame(width: 11, height: 11) }
                legend(L10n.Common.notDone) {
                    Circle().strokeBorder(AppColors.outline, lineWidth: 1.5).frame(width: 10, height: 10)
                }
                legend(L10n.Common.planned) {
                    Circle().strokeBorder(AppColors.chevron, style: StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
                        .frame(width: 10, height: 10)
                }
                legend(L10n.Common.restDay) {
                    Text("12").font(.system(size: 10)).foregroundStyle(AppColors.textQuaternary)
                }
            }
            .padding(.top, 2)

            if let info = viewModel.selectedInfo {
                Text(info)
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppColors.fillSecondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.easeOut(duration: 0.2), value: viewModel.selectedInfo)
    }

    private func arrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? AppColors.accent : AppColors.chevron)
        .disabled(!enabled)
    }

    private func legend(_ title: String, @ViewBuilder mark: () -> some View) -> some View {
        HStack(spacing: 5) {
            mark()
            Text(title).font(.system(size: 11)).foregroundStyle(AppColors.textSecondary)
        }
    }
}

private struct DayCellView: View {
    let cell: HabitDetailViewModel.DayCell
    let tint: Color

    var body: some View {
        Group {
            if cell.day == nil {
                Color.clear
            } else {
                Text(cell.number)
                    .font(.system(size: 14, weight: isBold ? .semibold : .regular))
                    .foregroundStyle(foreground)
                    .frame(width: 34, height: 34)
                    .background { background }
                    .overlay {
                        if cell.isSelected {
                            Circle().stroke(AppColors.label, lineWidth: 1.5).padding(-3.5)
                        }
                    }
            }
        }
        .frame(height: 38)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var isBold: Bool { cell.state == .done || cell.state == .today }

    private var foreground: Color {
        switch cell.state {
        case .done: .white
        case .skipped, .planned: AppColors.textSecondary
        case .missed, .today: AppColors.label
        case .rest, .notStarted: AppColors.chevron
        }
    }

    @ViewBuilder
    private var background: some View {
        switch cell.state {
        case .done: Circle().fill(tint)
        case .skipped: SkipCircle()
        case .missed: Circle().strokeBorder(AppColors.outline, lineWidth: 1.5)
        case .planned: Circle().strokeBorder(AppColors.chevron, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
        case .today: Circle().strokeBorder(tint, lineWidth: 2)
        case .rest, .notStarted: EmptyView()
        }
    }
}

/// Круг с диагональной штриховкой — пропущенный день.
private struct SkipCircle: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(AppColors.insetFill))
            var path = Path()
            for x in stride(from: -size.height, through: size.width, by: 5) {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
            }
            context.stroke(path, with: .color(AppColors.chartLine), lineWidth: 2)
        }
        .clipShape(Circle())
    }
}

private struct TrendCard: View {
    let bars: [HabitDetailViewModel.TrendBar]
    let colorHex: String

    var body: some View {
        let tint = Color(hex: colorHex)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.HabitDetail.weeklyTrend)
                    .font(AppFont.headline)
                    .foregroundStyle(AppColors.label)
                Spacer()
                Text(L10n.HabitDetail.eightWeeks)
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            }
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(bars) { bar in
                    VStack(spacing: 6) {
                        Text(bar.value)
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.textTertiary)
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(bar.isCurrent ? tint : tint.opacity(0.4))
                            .frame(maxWidth: 22)
                            .frame(height: max(4, bar.fraction * 60))
                        Text(bar.label)
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.textTertiary)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 96, alignment: .bottom)
        }
        .padding(14)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
