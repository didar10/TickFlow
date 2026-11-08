import SwiftUI

struct CalendarView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var viewModel: CalendarViewModel

    init(viewModel: CalendarViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 0) {
            header
            content
        }
        .background(AppColors.surface.ignoresSafeArea())
        .overlay(alignment: .bottomTrailing) {
            FloatingAddButton { viewModel.beginCreatingTask() }
        }
        .taskEditor($viewModel.editorRequest)
        .onChange(of: viewModel.wantsNewTask, initial: true) { _, wants in
            if wants { viewModel.handleNewTaskRequest() }
        }
        .onChange(of: viewModel.preferredMode) { viewModel.applyPreferredMode() }
        .sheet(isPresented: $viewModel.isFilterPresented) {
            FilterSheetView(viewModel: dependencies.makeFilterSheetViewModel())
                .presentationDetents([.height(330)])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $viewModel.isSearchPresented) {
            SearchView(viewModel: dependencies.makeSearchViewModel())
        }
        .alert(dialogTitle, isPresented: dialogBinding, presenting: viewModel.dialog) { dialog in
            switch dialog {
            case .recurring:
                Button(L10n.Common.thisOccurrence) { viewModel.resolveRecurring(.thisOccurrence) }
                Button(L10n.Common.thisAndFollowing) { viewModel.resolveRecurring(.thisAndFollowing) }
                Button(L10n.Common.cancel, role: .cancel) { viewModel.cancelDialog() }
            case .conflict:
                Button(L10n.Common.keepBothMasculine) { viewModel.confirmConflict() }
                Button(L10n.Common.cancel, role: .cancel) { viewModel.cancelDialog() }
            }
        } message: { dialog in
            switch dialog {
            case .recurring(let message), .conflict(let message): Text(message)
            }
        }
        .confirmationDialog(
            viewModel.menuTask?.title ?? "",
            isPresented: menuBinding,
            titleVisibility: .visible,
            presenting: viewModel.menuTask
        ) { task in
            Button(task.isCompleted ? L10n.Calendar.markIncomplete : L10n.Common.completed) { viewModel.toggleFromMenu() }
            Button(L10n.Common.open) { viewModel.open(task.id) }
            Button(L10n.Common.delete, role: .destructive) { viewModel.deleteFromMenu() }
        }
    }

    private var dialogTitle: String {
        switch viewModel.dialog {
        case .recurring: L10n.Common.recurringTask
        case .conflict: L10n.Common.timeConflict
        case nil: ""
        }
    }

    private var dialogBinding: Binding<Bool> {
        Binding(get: { viewModel.dialog != nil }, set: { if !$0 { viewModel.dialog = nil } })
    }

    private var menuBinding: Binding<Bool> {
        Binding(get: { viewModel.menuTask != nil }, set: { if !$0 { viewModel.menuTask = nil } })
    }

    // MARK: - Шапка

    /// Одна строка: кнопка вида · месяц и год (свайп листает период) · поиск · фильтр · «Сегодня».
    private var header: some View {
        @Bindable var viewModel = viewModel

        return HStack(spacing: 4) {
            Menu {
                Picker(L10n.Calendar.view, selection: $viewModel.mode) {
                    ForEach(viewModel.modeOptions, id: \.value) { option in
                        Label(option.title, systemImage: option.value.symbolName).tag(option.value)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: viewModel.mode.symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.label)
                    .frame(width: 38, height: 38)
                    .background(AppColors.fillTertiary, in: Circle())
                    .contentShape(Circle())
            }
            .accessibilityLabel(L10n.Calendar.viewMenu)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(viewModel.title)
                    .font(.system(size: 24, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(AppColors.label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(viewModel.year)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppColors.textQuaternary)
                    .lineLimit(1)
                    .layoutPriority(-1)
                Spacer(minLength: 0)
            }
            .padding(.leading, 4)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 30).onEnded { viewModel.swipe(dx: $0.translation.width, dy: $0.translation.height) })

            iconButton("magnifyingglass", label: L10n.Common.search) { viewModel.isSearchPresented = true }
            iconButton("line.3.horizontal.decrease", label: L10n.Common.filter, showsDot: viewModel.isFilterActive) {
                viewModel.isFilterPresented = true
            }

            Button(L10n.Common.today, action: viewModel.goToToday)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .padding(.horizontal, 11)
                .frame(height: 30)
                .background(AppColors.accentSoft, in: Capsule())
                .fixedSize()
                .buttonStyle(.plain)
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(AppColors.surface)
    }

    private func iconButton(_ symbol: String, label: String, showsDot: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColors.label)
                .frame(width: 34, height: 32)
                .contentShape(Rectangle())
                .overlay(alignment: .topTrailing) {
                    if showsDot {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(AppColors.surface, lineWidth: 1.5))
                            .offset(x: -5, y: 4)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Содержимое

    @ViewBuilder
    private var content: some View {
        if viewModel.isMonth {
            ScrollView {
                VStack(spacing: 0) {
                    MonthGrid(viewModel: viewModel)
                    AgendaList(viewModel: viewModel)
                }
                .padding(.bottom, 100)
            }
            .background(AppColors.background)
        } else {
            TimeGridView(viewModel: viewModel)
                .overlay {
                    if viewModel.isFirstRun {
                        FirstRunCard(viewModel: viewModel)
                    } else if viewModel.isDayEmpty {
                        DayEmptyCard()
                    }
                }
        }
    }
}

/// Пустой календарь при первом запуске.
private struct FirstRunCard: View {
    let viewModel: CalendarViewModel

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(AppColors.accent)
                .frame(width: 56, height: 56)
                .background(AppColors.accentSoft, in: Circle())
                .padding(.bottom, 4)
            Text(L10n.Calendar.emptyTitle)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppColors.label)
            Text(L10n.Calendar.emptyMessage)
                .font(AppFont.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            Button(action: viewModel.beginCreatingTask) {
                Text(L10n.Calendar.createFirstTask)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            Button(action: viewModel.addFirstHabit) {
                Text(L10n.Calendar.addFirstHabit)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(AppColors.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            Button(L10n.Common.loadSample, action: viewModel.loadSample)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppColors.accent)
                .padding(.top, 4)
        }
        .buttonStyle(.plain)
        .padding(22)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 20, y: 6)
        .padding(.horizontal, 28)
    }
}

/// Подсказка на пустом дне в виде «День».
private struct DayEmptyCard: View {
    var body: some View {
        VStack(spacing: 4) {
            Text(L10n.Calendar.nothingScheduled)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.label)
            Text(L10n.Calendar.tapTimeToAdd)
                .font(AppFont.footnote)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(AppColors.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        .allowsHitTesting(false)
    }
}
