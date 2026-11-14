import SwiftUI

struct FocusHistoryView: View {
    @State private var viewModel: FocusHistoryViewModel

    init(viewModel: FocusHistoryViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.Focus.historyTitle)
                    .font(AppFont.largeTitle)
                    .tracking(-0.5)
                    .foregroundStyle(AppColors.label)
                    .padding(.horizontal, 4)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(viewModel.stats) { stat in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stat.title).font(.system(size: 12)).foregroundStyle(AppColors.textSecondary)
                                Text(stat.value)
                                    .font(.system(size: 22, weight: .bold))
                                    .tracking(-0.4)
                                    .foregroundStyle(AppColors.label)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    MinutesBarChart(bars: viewModel.bars, maxValue: viewModel.maxBar, plotHeight: 44, maxBarWidth: 22)
                        .frame(height: 64, alignment: .bottom)
                }
                .padding(16)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                SegmentedPicker(options: FocusHistoryViewModel.Filter.allCases.map { ($0, $0.title) },
                                selection: $viewModel.filter)

                ForEach(viewModel.days) { day in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(day.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(AppColors.label)
                            Spacer()
                            Text(day.summary).font(AppFont.footnote).foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(.horizontal, 4)
                        SessionRowsCard(rows: day.rows, onTap: viewModel.open)
                    }
                }

                if viewModel.isEmpty {
                    Text(L10n.Focus.noMatches)
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                }
                if viewModel.hasMore {
                    Button(action: viewModel.showEarlier) {
                        Text(L10n.Focus.showEarlier)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.accent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .sheet(item: $viewModel.sessionDetail, onDismiss: viewModel.sessionClosed) { SessionDetailView(viewModel: $0) }
        .taskEditor($viewModel.editorRequest)
    }
}
