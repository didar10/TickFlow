import SwiftUI

struct TasksView: View {
    @State private var viewModel: TasksViewModel

    init(viewModel: TasksViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LargeHeader(title: L10n.Tab.tasks) { EmptyView() }
                    .padding(.bottom, 8)

                searchField
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                categoryChips
                    .padding(.bottom, 12)

                controls
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)

                if viewModel.hasAnyTasks {
                    todayCard
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }

                ForEach(viewModel.groups) { group in
                    groupSection(group)
                }

                if viewModel.showsNoResults {
                    EmptyStateView(
                        symbol: "magnifyingglass",
                        title: L10n.Tasks.noResultsTitle(viewModel.trimmedQueryText),
                        message: L10n.Tasks.noResultsMessage,
                        actionTitle: L10n.Tasks.clearSearch,
                        action: viewModel.clearQuery
                    )
                }
                if viewModel.showsNoTasks {
                    EmptyStateView(
                        symbol: "checklist",
                        title: L10n.Tasks.emptyTitle,
                        message: L10n.Tasks.emptyMessage,
                        actionTitle: L10n.Common.newTask,
                        action: viewModel.startCreating
                    )
                }
            }
            .padding(.bottom, 110)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(AppColors.background.ignoresSafeArea())
        .overlay(alignment: .bottomTrailing) {
            FloatingAddButton(action: viewModel.startCreating)
        }
        .taskEditor($viewModel.editorRequest)
    }

    // MARK: - Шапка

    private var searchField: some View {
        @Bindable var viewModel = viewModel

        return HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColors.textTertiary)
            TextField(L10n.Tasks.searchPlaceholder, text: $viewModel.query)
                .font(.system(size: 17))
                .foregroundStyle(AppColors.label)
                .submitLabel(.search)
            if viewModel.hasQuery {
                Button(action: viewModel.clearQuery) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(AppColors.textQuaternary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Tasks.clearSearch)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background(AppColors.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.categoryChips) { chip in
                    Chip(
                        title: chip.title,
                        isSelected: chip.isSelected,
                        dotColor: chip.colorHex.map { Color(hex: $0) },
                        selectedColor: AppColors.inverse,
                        unselectedBackground: AppColors.surface
                    ) {
                        viewModel.selectCategory(chip.id)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var controls: some View {
        HStack {
            Button(action: viewModel.toggleSort) {
                HStack(spacing: 4) {
                    Text(L10n.Tasks.sortLabel).foregroundStyle(AppColors.textSecondary)
                    Text(viewModel.sortTitle).fontWeight(.semibold).foregroundStyle(AppColors.accent)
                }
            }
            Spacer()
            Button(viewModel.densityToggleTitle, action: viewModel.toggleDensity)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.accent)
        }
        .font(AppFont.footnote)
        .buttonStyle(.plain)
    }

    private var todayCard: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.Common.today)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.label)
                Spacer()
                Text(viewModel.todaySummary)
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.textSecondary)
            }
            ProgressBar(progress: viewModel.todayProgress)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .card()
    }

    // MARK: - Группы

    private func groupSection(_ group: TasksViewModel.Group) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(group.title)
                    .font(AppFont.sectionTitle)
                    .tracking(-0.2)
                    .foregroundStyle(group.isDanger ? AppColors.danger : AppColors.label)
                Text("\(group.count)")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.textTertiary)
                if group.isCollapsible {
                    Spacer()
                    Button(group.toggleTitle, action: viewModel.toggleCompletedGroup)
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.accent)
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            if !group.rows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(group.rows.enumerated()), id: \.element.id) { index, row in
                        TaskRowView(item: row, isCompact: viewModel.isCompact) {
                            viewModel.toggle(row.id)
                        }
                        .onTapGesture { viewModel.open(row.id) }
                        .overlay(alignment: .bottom) {
                            if index < group.rows.count - 1 {
                                Rectangle().fill(AppColors.separator).frame(height: 0.5).padding(.leading, 50)
                            }
                        }
                    }
                }
                .card(cornerRadius: 12)
                .padding(.horizontal, 16)
            }
        }
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    TasksView(viewModel: dependencies.makeTasksViewModel())
        .environment(dependencies)
}
