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
                .padding(.trailing, 18)
                .padding(.bottom, 18)
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
                Button("Только это вхождение") { viewModel.resolveRecurring(.thisOccurrence) }
                Button("Это и следующие") { viewModel.resolveRecurring(.thisAndFollowing) }
                Button("Отмена", role: .cancel) { viewModel.cancelDialog() }
            case .conflict:
                Button("Оставить оба") { viewModel.confirmConflict() }
                Button("Отмена", role: .cancel) { viewModel.cancelDialog() }
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
            Button(task.isCompleted ? "Вернуть в работу" : "Выполнено") { viewModel.toggleFromMenu() }
            Button("Открыть") { viewModel.open(task.id) }
            Button("Удалить", role: .destructive) { viewModel.deleteFromMenu() }
        }
    }

    private var dialogTitle: String {
        switch viewModel.dialog {
        case .recurring: "Повторяющаяся задача"
        case .conflict: "Пересечение по времени"
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

    private var header: some View {
        @Bindable var viewModel = viewModel

        return VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(viewModel.title)
                    .font(AppFont.calendarTitle)
                    .tracking(-0.4)
                    .foregroundStyle(AppColors.label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(viewModel.year)
                    .font(AppFont.calendarTitle.weight(.regular))
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(1)
                    .layoutPriority(-1)
                Spacer(minLength: 4)
                navigation
                ProfileButton(action: viewModel.openSettings)
                    .padding(.leading, 4)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 8 }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 30).onEnded { viewModel.swipe(dx: $0.translation.width) })

            HStack(spacing: 8) {
                SegmentedPicker(options: viewModel.modeOptions, selection: $viewModel.mode)
                iconButton("magnifyingglass", label: "Поиск") { viewModel.isSearchPresented = true }
                iconButton("line.3.horizontal.decrease", label: "Фильтр", showsDot: viewModel.isFilterActive) {
                    viewModel.isFilterPresented = true
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(AppColors.surface)
    }

    private var navigation: some View {
        HStack(spacing: 0) {
            navButton("chevron.left", label: "Назад", action: viewModel.showPrevious)
            Button("Сегодня", action: viewModel.goToToday)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .padding(.horizontal, 11)
                .frame(height: 30)
                .background(AppColors.accentSoft, in: Capsule())
                .fixedSize()
                .buttonStyle(.plain)
            navButton("chevron.right", label: "Вперёд", action: viewModel.showNext)
        }
        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 8 }
    }

    private func navButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func iconButton(_ symbol: String, label: String, showsDot: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.labelSecondary)
                .frame(width: 34, height: 32)
                .background(AppColors.fill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if showsDot {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(AppColors.surface, lineWidth: 1.5))
                            .offset(x: 2, y: -2)
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
            Text("Календарь пуст")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppColors.label)
            Text("Добавьте задачу или привычку — или загрузите пример, чтобы посмотреть, как всё работает.")
                .font(AppFont.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            Button(action: viewModel.beginCreatingTask) {
                Text("Создать первую задачу")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            Button(action: viewModel.addFirstHabit) {
                Text("Добавить первую привычку")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(AppColors.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            Button("Загрузить пример", action: viewModel.loadSample)
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
            Text("Ничего не запланировано")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.label)
            Text("Нажмите на время, чтобы добавить задачу.")
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
