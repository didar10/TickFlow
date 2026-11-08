import SwiftUI

struct InsightsView: View {
    @State private var viewModel: InsightsViewModel

    init(viewModel: InsightsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LargeHeader(title: L10n.Insights.title) { EmptyView() }
                .padding(.bottom, 10)

                if viewModel.hasData {
                    let report = viewModel.report

                    SegmentedPicker(options: viewModel.rangeOptions, selection: $viewModel.range)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                    Text(L10n.Insights.periodCaption(report.period))
                        .font(AppFont.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    VStack(spacing: 8) {
                        KpiGrid(kpis: report.kpis)
                        ActivityChart(report: report)
                        if viewModel.hasHabits {
                            HabitConsistencyCard(report: report)
                        }
                        FactsCard(facts: report.facts)
                    }
                    .padding(.horizontal, 16)
                } else {
                    EmptyStateView(
                        symbol: "chart.bar",
                        title: L10n.Insights.emptyTitle,
                        message: L10n.Insights.emptyMessage
                    )
                }
            }
            .padding(.bottom, 30)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background, for: .navigationBar)
    }
}

private struct KpiGrid: View {
    let kpis: [InsightsViewModel.Kpi]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(kpis) { kpi in
                VStack(alignment: .leading, spacing: 4) {
                    Text(kpi.title)
                        .font(AppFont.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                    Text(kpi.value)
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.5)
                        .foregroundStyle(AppColors.label)
                        .contentTransition(.numericText())
                    Text(kpi.delta)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(kpi.isNeutral ? AppColors.textTertiary : kpi.isGood ? AppColors.success : AppColors.dangerText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}

private struct ActivityChart: View {
    let report: InsightsViewModel.Report

    private let plotHeight: CGFloat = 118

    var body: some View {
        let narrow = report.bars.count > 7
        let barWidth: CGFloat = narrow ? 7 : 12

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(report.chartTitle)
                    .font(AppFont.headline)
                    .foregroundStyle(AppColors.label)
                Spacer()
                legend(AppColors.accent, L10n.Common.completed)
                legend(AppColors.accentMuted, L10n.Common.created)
            }

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(report.bars) { bar in
                    VStack(spacing: 6) {
                        HStack(alignment: .bottom, spacing: 2) {
                            column(bar.created, color: AppColors.accentMuted, width: barWidth)
                            column(bar.completed, color: bar.isBest ? AppColors.accent : Color(hex: "#8F8EE6"), width: barWidth)
                        }
                        .frame(height: plotHeight, alignment: .bottom)
                        Text(bar.label)
                            .font(.system(size: 10, weight: bar.isBest ? .semibold : .regular))
                            .foregroundStyle(bar.isBest ? AppColors.label : AppColors.textTertiary)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .animation(.easeOut(duration: 0.35), value: report.bars.map(\.completed))

            Divider().overlay(AppColors.hairline)
            Text(report.note)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func column(_ value: Int, color: Color, width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color)
            .frame(width: width, height: max(value > 0 ? 3 : 0, CGFloat(value) / CGFloat(report.maxBarValue) * plotHeight))
    }

    private func legend(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(title).font(.system(size: 12)).foregroundStyle(AppColors.textSecondary)
        }
    }
}

private struct HabitConsistencyCard: View {
    let report: InsightsViewModel.Report

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.Insights.habitConsistency)
                    .font(AppFont.headline)
                    .foregroundStyle(AppColors.label)
                Spacer()
                Text(report.consistency)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColors.label)
            }
            ForEach(report.habits) { habit in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(habit.name).foregroundStyle(AppColors.label)
                        Spacer()
                        Text(habit.detail).foregroundStyle(AppColors.textSecondary)
                    }
                    .font(.system(size: 14))
                    ProgressBar(progress: habit.rate, tint: Color(hex: habit.colorHex), height: 6)
                }
            }
        }
        .padding(16)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct FactsCard: View {
    let facts: [InsightsViewModel.Fact]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(facts.enumerated()), id: \.element.id) { index, fact in
                HStack {
                    Text(fact.title).foregroundStyle(AppColors.labelSecondary)
                    Spacer()
                    Text(fact.value).fontWeight(.semibold).foregroundStyle(AppColors.label)
                }
                .font(.system(size: 15))
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                if index < facts.count - 1 {
                    Divider().overlay(AppColors.hairline).padding(.leading, 16)
                }
            }
        }
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
