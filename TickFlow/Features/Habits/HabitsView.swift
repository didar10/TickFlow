import SwiftUI

struct HabitsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var viewModel: HabitsViewModel

    init(viewModel: HabitsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack(path: $viewModel.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    LargeHeader(title: L10n.Tab.habits) {
                        Button { viewModel.startCreating() } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(AppColors.accent, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.Habits.new)
                    }
                    Text(viewModel.dateLabel)
                        .font(AppFont.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 2)
                        .padding(.bottom, 14)

                    if viewModel.hasHabits {
                        SummaryCard(viewModel: viewModel)
                        Text(L10n.Common.today)
                            .font(AppFont.sectionTitle)
                            .foregroundStyle(AppColors.label)
                            .padding(.horizontal, 20)
                            .padding(.top, 22)
                            .padding(.bottom, 8)
                        VStack(spacing: 8) {
                            ForEach(viewModel.rows) { row in
                                HabitRowView(row: row) {
                                    viewModel.tap(row.id)
                                } onOpen: {
                                    viewModel.open(row.id)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    } else {
                        EmptyHabitsCard(viewModel: viewModel)
                    }
                }
                .padding(.bottom, 110)
            }
            .background(AppColors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationTitle(L10n.Tab.habits)
            .navigationDestination(for: UUID.self) { id in
                HabitDetailView(viewModel: dependencies.makeHabitDetailViewModel(id: id))
            }
        }
        .sheet(item: $viewModel.editorRequest) { request in
            HabitEditorView(viewModel: dependencies.makeHabitEditorViewModel(request: request))
        }
        .onChange(of: viewModel.wantsNewHabit, initial: true) { _, wants in
            if wants { viewModel.handleNewHabitRequest() }
        }
    }
}

private struct SummaryCard: View {
    let viewModel: HabitsViewModel

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    ProgressRing(progress: viewModel.ringProgress, lineWidth: 7)
                    Text(viewModel.ringLabel)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppColors.label)
                }
                .frame(width: 68, height: 68)

                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.summary)
                        .font(AppFont.headline)
                        .foregroundStyle(AppColors.label)
                    Text(viewModel.summarySubtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                ForEach(viewModel.week) { day in
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(AppColors.fillSecondary)
                            if let fraction = day.fraction, fraction > 0 {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(day.isToday ? AppColors.accent : AppColors.accentFaded)
                                    .frame(height: 44 * max(fraction, 0.1))
                            }
                        }
                        .frame(maxWidth: 32)
                        .frame(height: 44)
                        .animation(.easeOut(duration: 0.4), value: day.fraction)

                        Text(day.letter)
                            .font(.system(size: 12, weight: day.isToday ? .bold : .medium))
                            .foregroundStyle(day.isToday ? AppColors.accent
                                             : day.fraction == nil ? AppColors.chevron : AppColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16)
    }
}

private struct HabitRowView: View {
    let row: HabitsViewModel.Row
    let onTap: () -> Void
    let onOpen: () -> Void

    var body: some View {
        let tint = Color(hex: row.colorHex)

        HStack(spacing: 14) {
            HabitIcon(symbol: row.symbolName, colorHex: row.colorHex, size: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.label)
                Text(row.subtitle)
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColors.textTertiary)
                if row.isMeasurable {
                    ProgressBar(progress: row.progress, tint: tint, height: 4)
                        .frame(maxWidth: 160)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                Text(row.streak)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColors.label)
                Text(L10n.Common.streak)
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(.trailing, 2)

            Button(action: onTap) {
                ZStack {
                    ProgressRing(progress: row.progress, tint: tint, lineWidth: 3.5)
                    if row.isDone {
                        Circle()
                            .fill(tint)
                            .padding(4)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(tint)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .animation(.spring(duration: 0.3), value: row.isDone)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: row.isDone) { _, new in new }
            .accessibilityLabel(row.isDone ? L10n.Common.unmark : L10n.Common.mark)
        }
        .padding(.vertical, 14)
        .padding(.leading, 16)
        .padding(.trailing, 14)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }
}

private struct EmptyHabitsCard: View {
    let viewModel: HabitsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.Habits.emptyTitle)
                .font(AppFont.sectionTitle)
                .foregroundStyle(AppColors.label)
            Text(L10n.Habits.emptyMessage)
                .font(AppFont.subheadline)
                .foregroundStyle(AppColors.textSecondary)
            FlowLayout(spacing: 8) {
                ForEach(viewModel.suggestions) { suggestion in
                    Button(suggestion.name) { viewModel.startCreating(suggestion) }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.label)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(AppColors.fillSecondary, in: Capsule())
                        .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

/// Иконка привычки на мягкой подложке её цвета.
struct HabitIcon: View {
    let symbol: String
    let colorHex: String
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.48, weight: .regular))
            .foregroundStyle(Color(hex: colorHex))
            .frame(width: size, height: size)
            .background(Color(hex: colorHex).opacity(0.1), in: RoundedRectangle(cornerRadius: size * 0.29, style: .continuous))
    }
}
