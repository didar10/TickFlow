import SwiftUI

/// «Учтённое время» в аналитике: итоги, график, фокус и перерывы, категории, оценка и факт.
struct TimeTrackedSection: View {
    let report: TimeReport

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.Calendar.trackedTime)
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.2)
                    .foregroundStyle(AppColors.label)
                Spacer()
                NavigationLink(value: FocusRoute.history) {
                    Text(L10n.Focus.historyTitle).font(.system(size: 15)).foregroundStyle(AppColors.accent)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 2)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(report.kpis) { kpi in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kpi.title).font(AppFont.footnote).foregroundStyle(AppColors.textSecondary).lineLimit(1)
                        Text(kpi.value)
                            .font(.system(size: 26, weight: .bold))
                            .tracking(-0.5)
                            .foregroundStyle(AppColors.label)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(kpi.detail)
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            trendCard
            if !report.categories.isEmpty { categoriesCard }
            if !report.tasks.isEmpty { tasksCard }
        }
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(report.trendTitle).font(AppFont.headline).foregroundStyle(AppColors.label)
                Spacer()
                Text(report.trendAverage).font(AppFont.footnote).foregroundStyle(AppColors.textSecondary)
            }
            MinutesBarChart(bars: report.bars.map { ($0.id, $0.label, $0.minutes, $0.isCurrent) }, maxValue: report.maxBar,
                            plotHeight: 92, maxBarWidth: 26)
                .frame(height: 118, alignment: .bottom)

            Divider().overlay(AppColors.hairline)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.Focus.focusVsBreak).foregroundStyle(AppColors.label)
                    Spacer()
                    Text(L10n.Focus.focusShare("\(Int((report.focusShare * 100).rounded()))%")).foregroundStyle(AppColors.textSecondary)
                }
                .font(.system(size: 14))
                GeometryReader { proxy in
                    let focusWidth = (proxy.size.width - 2) * report.focusShare
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 4).fill(AppColors.accent).frame(width: max(0, focusWidth))
                        RoundedRectangle(cornerRadius: 4).fill(AppColors.breakTint.opacity(0.55))
                    }
                }
                .frame(height: 8)
                HStack(spacing: 16) {
                    legend(AppColors.accent, L10n.Focus.focusLegend(DateFormatting.duration(minutes: report.focusMinutes)))
                    legend(AppColors.breakTint.opacity(0.55), L10n.Focus.breaksLegend(DateFormatting.duration(minutes: report.breakMinutes)))
                }
            }
        }
        .padding(16)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Focus.byCategory).font(AppFont.headline).foregroundStyle(AppColors.label)
            ForEach(report.categories) { row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(row.name).foregroundStyle(AppColors.label)
                        Spacer()
                        Text(row.value).monospacedDigit().foregroundStyle(AppColors.textSecondary)
                    }
                    .font(.system(size: 14))
                    ProgressBar(progress: Double(row.minutes) / Double(report.maxCategory),
                                tint: row.colorHex.map { Color(hex: $0) } ?? AppColors.chevron, height: 6)
                }
            }
        }
        .padding(16)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var tasksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.Focus.estimateVsActual).font(AppFont.headline).foregroundStyle(AppColors.label)
                Spacer()
                legend(AppColors.accentMuted, L10n.Focus.estimateLegend)
                legend(AppColors.accent, L10n.Focus.actualLegend)
            }
            ForEach(report.tasks) { row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text(row.title).foregroundStyle(AppColors.label).lineLimit(1)
                        Spacer(minLength: 0)
                        Text(row.value)
                            .fontWeight(row.isOver ? .semibold : .regular)
                            .foregroundStyle(row.isOver ? AppColors.warningText : AppColors.textSecondary)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .font(.system(size: 14))
                    GeometryReader { proxy in
                        let scale = proxy.size.width / CGFloat(report.taskScale)
                        ZStack(alignment: .leading) {
                            if let estimate = row.estimate {
                                RoundedRectangle(cornerRadius: 4).fill(AppColors.accentMuted)
                                    .frame(width: CGFloat(estimate) * scale)
                            }
                            RoundedRectangle(cornerRadius: 3)
                                .fill(row.isOver ? AppColors.warning : AppColors.accent)
                                .frame(width: CGFloat(row.actual) * scale)
                                .padding(.vertical, 2)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding(16)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func legend(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(title).font(.system(size: 12)).foregroundStyle(AppColors.textSecondary)
        }
    }
}

/// Столбики минут: текущий период темнее, пустые — бледные.
struct MinutesBarChart: View {
    let bars: [(id: Int, label: String, minutes: Int, isCurrent: Bool)]
    let maxValue: Int
    let plotHeight: CGFloat
    let maxBarWidth: CGFloat

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(bars, id: \.id) { bar in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(bar.isCurrent ? AppColors.accent : Color(hex: "#8F8EE6"))
                        .opacity(bar.minutes > 0 ? 1 : 0.3)
                        .frame(maxWidth: maxBarWidth)
                        .frame(height: max(3, CGFloat(bar.minutes) / CGFloat(maxValue) * plotHeight))
                    Text(bar.label)
                        .font(.system(size: 10, weight: bar.isCurrent ? .semibold : .regular))
                        .foregroundStyle(bar.isCurrent ? AppColors.label : AppColors.textTertiary)
                        .lineLimit(1)
                        .fixedSize()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(bars.map { $0.label + " " + DateFormatting.duration(minutes: $0.minutes) }.joined(separator: ", "))
    }
}
