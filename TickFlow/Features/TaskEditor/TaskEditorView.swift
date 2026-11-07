import SwiftUI

/// Редактор задачи. `container` — в чём показан экран: лист быстрого создания
/// или полноэкранный редактор. Одна ViewModel переходит из листа в полный экран.
struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TaskEditorViewModel
    @FocusState private var focus: TaskEditorViewModel.Field?
    private let container: TaskEditorViewModel.Mode
    /// Закрытие панели быстрого создания. Полный экран закрывается через `dismiss`.
    private let onClose: (() -> Void)?

    init(viewModel: TaskEditorViewModel, container: TaskEditorViewModel.Mode, onClose: (() -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.container = container
        self.onClose = onClose
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        Group {
            switch container {
            case .quick:
                quickLayout
            case .full:
                fullLayout
            }
        }
        .sheet(item: $viewModel.picker) { picker in
            DateTimePickerView(viewModel: picker, onCancel: viewModel.closePicker)
        }
        .alert(
            L10n.Common.timeConflict,
            isPresented: dialogBinding(.conflict(message: "")),
            presenting: viewModel.dialog
        ) { _ in
            Button(L10n.Common.keepBoth, action: viewModel.confirmConflict)
            Button(L10n.Common.cancel, role: .cancel, action: viewModel.cancelDialog)
        } message: { dialog in
            if case .conflict(let message) = dialog { Text(message) }
        }
        .confirmationDialog(
            L10n.Common.recurringTask,
            isPresented: dialogBinding(.recurring(message: "")),
            titleVisibility: .visible,
            presenting: viewModel.dialog
        ) { _ in
            Button(L10n.Common.thisOccurrence) { viewModel.resolveRecurring(.thisOccurrence) }
            Button(L10n.Common.thisAndFollowing) { viewModel.resolveRecurring(.thisAndFollowing) }
            Button(L10n.Common.cancel, role: .cancel, action: viewModel.cancelDialog)
        } message: { dialog in
            if case .recurring(let message) = dialog { Text(message) }
        }
        .confirmationDialog(
            L10n.Editor.deleteTaskQuestion,
            isPresented: dialogBinding(.delete),
            titleVisibility: .hidden
        ) {
            Button(L10n.Editor.deleteTask, role: .destructive, action: viewModel.confirmDelete)
            Button(L10n.Common.cancel, role: .cancel, action: viewModel.cancelDialog)
        } message: {
            Text(L10n.Editor.deleteTaskMessage)
        }
        .onChange(of: viewModel.isFinished) { _, finished in
            if finished { close() }
        }
        .onChange(of: viewModel.mode) { _, mode in
            // «Открыть во весь экран»: лист закрывается, полный экран откроет презентер.
            if container == .quick, mode == .full { close() }
        }
        .onChange(of: viewModel.focusRequest, initial: true) { _, request in
            // Запрос фокуса обрабатывает только экран, который сейчас активен.
            guard let request, viewModel.mode == container else { return }
            focus = request
            viewModel.focusRequest = nil
        }
    }

    /// Привязка `isPresented` к конкретному виду диалога.
    private func dialogBinding(_ kind: TaskEditorViewModel.Dialog) -> Binding<Bool> {
        Binding(
            get: { viewModel.dialog?.id == kind.id },
            set: { if !$0, viewModel.dialog?.id == kind.id { viewModel.cancelDialog() } }
        )
    }

    // MARK: - Быстрое создание

    private var quickLayout: some View {
        @Bindable var viewModel = viewModel

        return VStack(alignment: .leading, spacing: 6) {
            TextField(L10n.Editor.titlePlaceholder, text: $viewModel.title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppColors.label)
                .focused($focus, equals: .title)
                .submitLabel(.done)
                .onSubmit(viewModel.submitTitle)

            TextField(L10n.Editor.notesPlaceholder, text: $viewModel.notes, axis: .vertical)
                .font(.system(size: 15))
                .foregroundStyle(AppColors.labelSecondary)
                .lineLimit(1...6)
                .focused($focus, equals: .notes)

            HStack(spacing: 2) {
                if viewModel.hasDate {
                    Button(action: viewModel.openPicker) {
                        Label(viewModel.whenShort, systemImage: "calendar")
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                            .foregroundStyle(AppColors.accent)
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(AppColors.accentSoft, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)
                } else {
                    toolbarIcon("calendar", color: AppColors.textTertiary, action: viewModel.openPicker)
                        .accessibilityLabel(L10n.Common.date)
                }

                priorityMenu(iconColor: viewModel.hasPriority ? viewModel.priority.color : AppColors.textTertiary)
                categoryMenu {
                    toolbarIconLabel("tag", color: viewModel.isCategoryExplicit ? Color(hex: viewModel.categoryColorHex) : AppColors.textTertiary)
                }
                Menu {
                    Button(L10n.Editor.openFullScreen, systemImage: "arrow.up.left.and.arrow.down.right", action: viewModel.openFullScreen)
                } label: {
                    toolbarIconLabel("ellipsis", color: AppColors.textTertiary)
                }
                .accessibilityLabel(L10n.Common.more)

                Spacer(minLength: 0)

                Button(action: viewModel.save) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(viewModel.canSave ? AppColors.accent : AppColors.doneDot, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canSave)
                .accessibilityLabel(L10n.Common.add)
            }
            .frame(height: 44)
            .padding(.horizontal, -8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 6)
    }

    // MARK: - Полный экран

    private var fullLayout: some View {
        @Bindable var viewModel = viewModel

        return VStack(spacing: 0) {
            fullTopBar

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: viewModel.openPicker) {
                        HStack(spacing: 10) {
                            if viewModel.isEditing {
                                CompletionBox(isOn: viewModel.isCompleted, tint: Color(hex: viewModel.categoryColorHex), action: viewModel.toggleCompleted)
                            } else {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .strokeBorder(AppColors.chevron, lineWidth: 1.6)
                                    .frame(width: 20, height: 20)
                            }
                            Text(viewModel.whenFull)
                                .font(.system(size: 15, weight: viewModel.hasDate ? .medium : .regular))
                                .foregroundStyle(viewModel.hasDate ? AppColors.accent : AppColors.textTertiary)
                            if viewModel.hasReminderOrRepeat {
                                Image(systemName: "bell")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppColors.textTertiary)
                            }
                        }
                        .frame(height: 28)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    TextField(L10n.Editor.titlePlaceholder, text: $viewModel.title, axis: .vertical)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppColors.label)
                        .focused($focus, equals: .title)
                        .submitLabel(.next)
                        .onChange(of: viewModel.title) { _, value in
                            // Многострочное поле не вызывает onSubmit: перехватываем перевод строки.
                            guard value.contains("\n") else { return }
                            viewModel.title = value.replacingOccurrences(of: "\n", with: "")
                            viewModel.submitTitle()
                        }

                    TextField(L10n.Editor.notesPlaceholder, text: $viewModel.notes, axis: .vertical)
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.labelSecondary)
                        .lineLimit(3...)
                        .focused($focus, equals: .notes)

                    subtasksSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)

            fullBottomBar
        }
        .background(AppColors.surface)
    }

    private var fullTopBar: some View {
        HStack(spacing: 8) {
            Button(action: viewModel.back) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.label)
                    .frame(width: 40, height: 40)
                    .background(AppColors.fillSecondary, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Common.back)

            categoryMenu {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Color(hex: viewModel.categoryColorHex))
                        .frame(width: 10, height: 10)
                    Text(viewModel.categoryName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.label)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.textTertiary)
                }
                .padding(.horizontal, 6)
                .frame(height: 40)
            }

            Spacer(minLength: 0)

            priorityMenu(iconColor: viewModel.hasPriority ? viewModel.priority.color : AppColors.label, filled: true)

            Menu {
                if viewModel.isEditing {
                    Button(
                        viewModel.isCompleted ? L10n.Common.markUndone : L10n.Common.markDone,
                        systemImage: viewModel.isCompleted ? "circle" : "checkmark.circle",
                        action: viewModel.toggleCompleted
                    )
                    Button(L10n.Editor.duplicate, systemImage: "plus.square.on.square", action: viewModel.duplicate)
                    Button(L10n.Common.delete, systemImage: "trash", role: .destructive, action: viewModel.requestDelete)
                } else {
                    Button(L10n.Editor.discardDraft, systemImage: "trash", role: .destructive, action: viewModel.discard)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.label)
                    .frame(width: 40, height: 40)
                    .background(AppColors.fillSecondary, in: Circle())
            }
            .accessibilityLabel(L10n.Common.more)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var subtasksSection: some View {
        @Bindable var viewModel = viewModel

        return VStack(alignment: .leading, spacing: 0) {
            Divider().overlay(AppColors.separator)
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.Editor.subtasksHeader)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Text(viewModel.subtaskCount)
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(.top, 10)
            .padding(.bottom, 2)

            ForEach(viewModel.subtasks) { subtask in
                HStack(spacing: 12) {
                    CheckCircle(isOn: subtask.isCompleted, tint: Color(hex: viewModel.categoryColorHex), size: 20) {
                        viewModel.toggleSubtask(subtask.id)
                    }
                    TextField("", text: Binding(
                        get: { subtask.title },
                        set: { viewModel.renameSubtask(subtask.id, to: $0) }
                    ))
                    .font(AppFont.body)
                    .foregroundStyle(subtask.isCompleted ? AppColors.textQuaternary : AppColors.label)
                    .strikethrough(subtask.isCompleted)
                    Button { viewModel.deleteSubtask(subtask.id) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.textQuaternary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.Editor.deleteSubtask)
                }
                .frame(minHeight: 44)
                .overlay(alignment: .bottom) { Divider().overlay(AppColors.hairline) }
            }

            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 20)
                TextField(L10n.Editor.addSubtask, text: $viewModel.newSubtaskTitle)
                    .font(AppFont.body)
                    .focused($focus, equals: .subtask)
                    .submitLabel(.next)
                    .onSubmit(viewModel.addSubtask)
                Button(L10n.Common.add, action: viewModel.addSubtask)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                    .buttonStyle(.plain)
                    .opacity(viewModel.canAddSubtask ? 1 : 0)
                    .disabled(!viewModel.canAddSubtask)
            }
            .frame(minHeight: 44)
        }
    }

    private var fullBottomBar: some View {
        HStack {
            HStack(spacing: 2) {
                categoryMenu {
                    toolbarIconLabel("tag", color: Color(hex: viewModel.categoryColorHex))
                }
                toolbarIcon("list.bullet", color: AppColors.label, action: viewModel.focusNewSubtask)
                    .accessibilityLabel(L10n.Editor.addSubtask)
            }
            .padding(.horizontal, 6)
            .frame(height: 44)
            .background(AppColors.surface, in: Capsule())
            .shadow(color: AppColors.label.opacity(0.06), radius: 5, y: 2)
            .overlay(Capsule().strokeBorder(AppColors.separator, lineWidth: 0.5))

            Spacer()

            if focus != nil {
                Button { focus = nil } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 18))
                        .foregroundStyle(AppColors.label)
                        .frame(width: 44, height: 44)
                        .background(AppColors.surface, in: Circle())
                        .overlay(Circle().strokeBorder(AppColors.separator, lineWidth: 0.5))
                        .shadow(color: AppColors.label.opacity(0.06), radius: 5, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Editor.hideKeyboard)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Меню

    private func categoryMenu<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        Menu {
            ForEach(viewModel.categories) { option in
                Button {
                    viewModel.selectCategory(option.id)
                } label: {
                    if option.isSelected {
                        SwiftUI.Label(option.name, systemImage: "checkmark")
                    } else {
                        Text(option.name)
                    }
                }
            }
        } label: {
            label()
        }
        .accessibilityLabel(L10n.Common.category)
    }

    private func priorityMenu(iconColor: Color, filled: Bool = false) -> some View {
        Menu {
            ForEach(viewModel.priorities) { option in
                Button {
                    viewModel.selectPriority(option.priority)
                } label: {
                    SwiftUI.Label(option.priority.menuTitle, systemImage: option.isSelected ? "checkmark" : "flag")
                }
            }
        } label: {
            if filled {
                Image(systemName: "flag")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 40, height: 40)
                    .background(AppColors.fillSecondary, in: Circle())
            } else {
                toolbarIconLabel("flag", color: iconColor)
            }
        }
        .accessibilityLabel(L10n.Common.priority)
    }

    private func toolbarIcon(_ symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            toolbarIconLabel(symbol, color: color)
        }
        .buttonStyle(.plain)
    }

    private func toolbarIconLabel(_ symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 19))
            .foregroundStyle(color)
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
    }
}

/// Квадратный чекбокс выполнения в шапке полного редактора.
private struct CompletionBox: View {
    let isOn: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isOn {
                    RoundedRectangle(cornerRadius: 5, style: .continuous).fill(tint)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white)
                } else {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(AppColors.chevron, lineWidth: 1.6)
                }
            }
            .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? L10n.Common.unmark : L10n.Common.markDone)
    }
}

// MARK: - Открытие редактора

/// Показывает редактор: новую задачу — панелью быстрого создания, существующую — во весь экран.
/// При переходе из панели в полный экран ViewModel та же, поэтому черновик не теряется.
private struct TaskEditorPresenter: ViewModifier {
    @Environment(AppDependencies.self) private var dependencies
    @Binding var request: TaskEditorRequest?

    @State private var editor: TaskEditorViewModel?
    @State private var isFullPresented = false

    func body(content: Content) -> some View {
        content
            .onChange(of: request?.id, initial: true) {
                guard let request, editor == nil else { return }
                let created = dependencies.makeTaskEditorViewModel(request: request)
                editor = created
                if created.mode == .quick {
                    dependencies.quickEditorHost.show(created, onClose: quickClosed)
                } else {
                    isFullPresented = true
                }
            }
            .fullScreenCover(isPresented: $isFullPresented, onDismiss: finish) {
                if let editor { TaskEditorView(viewModel: editor, container: .full) }
            }
    }

    /// Панель закрыта: либо задача сохранена или отброшена, либо выбран полный экран.
    private func quickClosed() {
        if let editor, editor.mode == .full, !editor.isFinished {
            isFullPresented = true
        } else {
            finish()
        }
    }

    private func finish() {
        editor = nil
        request = nil
    }
}

extension View {
    /// Показывает редактор задачи, пока `request` не `nil`.
    func taskEditor(_ request: Binding<TaskEditorRequest?>) -> some View {
        modifier(TaskEditorPresenter(request: request))
    }
}
