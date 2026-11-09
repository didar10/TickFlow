import SwiftUI

// MARK: - Остановка

extension View {
    /// Вопрос «Завершить сессию?» и лист сохранения таймера после нажатия «Стоп».
    func focusStopFlow(_ flow: FocusStopFlow) -> some View {
        modifier(FocusStopFlowModifier(flow: flow))
    }
}

private struct FocusStopFlowModifier: ViewModifier {
    @Bindable var flow: FocusStopFlow

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                L10n.Focus.endSessionTitle,
                isPresented: Binding(get: { flow.confirmation != nil }, set: { if !$0 { flow.keepGoing() } }),
                titleVisibility: .visible,
                presenting: flow.confirmation
            ) { confirmation in
                Button(L10n.Focus.saveMinutes(confirmation.minutes), action: flow.saveInterrupted)
                Button(L10n.Focus.discardSession, role: .destructive, action: flow.discard)
                Button(L10n.Focus.resume, role: .cancel, action: flow.keepGoing)
            } message: { confirmation in
                Text(L10n.Focus.endSessionMessage(confirmation.minutes, confirmation.total))
            }
            .sheet(item: $flow.timerEntry, onDismiss: flow.timerSheetDismissed) { editor in
                TimeEntryEditorView(viewModel: editor)
            }
    }
}

// MARK: - Запись времени

struct TimeEntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: TimeEntryEditorViewModel

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: viewModel.title,
                leadingTitle: L10n.Common.cancel, leading: viewModel.cancel,
                trailingTitle: L10n.Common.save, isTrailingEnabled: viewModel.isValid, trailing: viewModel.save
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsGroup("") {
                        Button { viewModel.isTaskPickerPresented = true } label: {
                            HStack(spacing: 8) {
                                Text(L10n.Focus.task).foregroundStyle(AppColors.label)
                                Spacer(minLength: 8)
                                Text(viewModel.taskTitle)
                                    .foregroundStyle(viewModel.hasTask ? AppColors.label : AppColors.textSecondary)
                                    .lineLimit(1)
                                Chevron()
                            }
                            .font(AppFont.body)
                            .settingsRow()
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        SettingsGroup("") {
                            StepperRow(title: L10n.Common.date, value: viewModel.dayText,
                                       decrement: { viewModel.stepDay(-1) }, increment: { viewModel.stepDay(1) })
                            SettingsDivider()
                            StepperRow(title: L10n.Common.start, value: viewModel.startText,
                                       decrement: { viewModel.stepStart(-5) }, increment: { viewModel.stepStart(5) })
                            SettingsDivider()
                            StepperRow(title: L10n.Common.end, value: viewModel.endText,
                                       decrement: { viewModel.stepEnd(-5) }, increment: { viewModel.stepEnd(5) })
                            SettingsDivider()
                            ValueRow(L10n.Focus.duration, value: viewModel.durationText)
                        }
                        if let footnote = viewModel.footnote { SettingsFootnote(footnote) }
                    }

                    if let error = viewModel.errorText {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.danger)
                            .padding(.horizontal, 4)
                    }
                    if viewModel.canDelete {
                        SheetActionButton(title: L10n.Focus.deleteEntry, style: .danger, action: viewModel.delete)
                    }
                    if viewModel.canDiscard {
                        SheetActionButton(title: L10n.Focus.discard, style: .danger, action: viewModel.discard)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 34)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .presentationDetents([.large])
        .sheet(isPresented: $viewModel.isTaskPickerPresented) {
            TaskPickerView(options: viewModel.taskOptions, selectedID: viewModel.task?.id, onSelect: viewModel.selectTask(id:))
        }
        .onChange(of: viewModel.isFinished) { _, finished in
            if finished { dismiss() }
        }
    }
}

// MARK: - Выбор задачи

struct TaskPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let options: [TaskPickerOption]
    let selectedID: UUID?
    let onSelect: (UUID?) -> Void

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: L10n.Focus.linkTask, leadingTitle: L10n.Common.cancel, leading: { dismiss() })
            ScrollView {
                VStack(spacing: 16) {
                    SettingsGroup("") {
                        row(id: nil, title: L10n.Focus.noTask, colorHex: nil, when: nil)
                    }
                    if !options.isEmpty {
                        SettingsGroup("") {
                            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                                row(id: option.id, title: option.title, colorHex: option.colorHex, when: option.when)
                                if index < options.count - 1 { SettingsDivider() }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 34)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }

    private func row(id: UUID?, title: String, colorHex: String?, when: String?) -> some View {
        Button {
            onSelect(id)
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(colorHex.map { Color(hex: $0) } ?? AppColors.chevron)
                    .frame(width: 10, height: 10)
                Text(title)
                    .font(AppFont.body)
                    .foregroundStyle(AppColors.label)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if id == selectedID {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                } else if let when {
                    Text(when).font(AppFont.subheadline).foregroundStyle(AppColors.textSecondary)
                }
            }
            .settingsRow()
            .frame(minHeight: 48)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Сессия

struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SessionDetailViewModel

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: L10n.Focus.sessionTitle,
                leadingTitle: L10n.Common.close, leading: { dismiss() },
                trailingTitle: L10n.Common.edit, trailing: viewModel.edit
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(viewModel.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppColors.label)
                        FlowLayout(spacing: 6, lineSpacing: 6) {
                            ForEach(viewModel.pills) { pill in
                                PillView(pill: pill)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    rows(L10n.Focus.actual, viewModel.actualRows)

                    if !viewModel.planRows.isEmpty {
                        SettingsGroup(L10n.Focus.plan) {
                            ForEach(viewModel.planRows) { row in
                                ValueRow(row.title, value: row.value)
                                SettingsDivider()
                            }
                            if viewModel.canOpenTask {
                                Button(action: viewModel.openTask) {
                                    HStack {
                                        Text(L10n.Focus.openTask).foregroundStyle(AppColors.accent)
                                        Spacer()
                                        Chevron()
                                    }
                                    .font(AppFont.body)
                                    .settingsRow()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    SheetActionButton(title: L10n.Focus.deleteSession, style: .danger, action: viewModel.delete)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 34)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .sheet(item: $viewModel.editor, onDismiss: viewModel.editorClosed) { editor in
            TimeEntryEditorView(viewModel: editor)
        }
        .onChange(of: viewModel.isFinished) { _, finished in
            if finished { dismiss() }
        }
    }

    private func rows(_ title: String, _ rows: [SessionDetailViewModel.Row]) -> some View {
        SettingsGroup(title) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                ValueRow(row.title, value: row.value)
                if index < rows.count - 1 { SettingsDivider() }
            }
        }
    }
}

private struct PillView: View {
    let pill: SessionDetailViewModel.Pill

    var body: some View {
        let colors: (Color, Color) = switch pill.style {
        case .category(let hex): (Color(hex: hex).opacity(0.14), Color(hex: hex))
        case .accent: (AppColors.accentSoft, AppColors.accent)
        case .success: (AppColors.breakSoft, AppColors.success)
        case .warning: (AppColors.warningSoft, AppColors.warningText)
        case .neutral: (AppColors.fillSecondary, AppColors.textSecondary)
        }
        Text(pill.text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(colors.1)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(colors.0, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Настройки таймера

struct FocusSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: FocusSettingsViewModel

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: L10n.Focus.timerSettingsTitle, trailingTitle: L10n.Common.done, trailing: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.Focus.preset.uppercased())
                            .font(AppFont.footnote)
                            .tracking(0.3)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.horizontal, 16)
                        Picker(L10n.Focus.preset, selection: $viewModel.preset) {
                            ForEach(viewModel.presets, id: \.value) { Text($0.title).tag($0.value) }
                        }
                        .pickerStyle(.segmented)
                    }

                    SettingsGroup("") {
                        StepperRow(title: L10n.Focus.phaseFocus, value: viewModel.focusText,
                                   decrement: { viewModel.stepFocus(-1) }, increment: { viewModel.stepFocus(1) })
                        SettingsDivider()
                        StepperRow(title: L10n.Focus.phaseShortBreak, value: viewModel.shortBreakText,
                                   decrement: { viewModel.stepShortBreak(-1) }, increment: { viewModel.stepShortBreak(1) })
                        SettingsDivider()
                        StepperRow(title: L10n.Focus.phaseLongBreak, value: viewModel.longBreakText,
                                   decrement: { viewModel.stepLongBreak(-1) }, increment: { viewModel.stepLongBreak(1) })
                        SettingsDivider()
                        StepperRow(title: L10n.Focus.longBreakAfter, value: viewModel.longBreakEveryText,
                                   decrement: { viewModel.stepLongBreakEvery(-1) }, increment: { viewModel.stepLongBreakEvery(1) })
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        SettingsGroup("") {
                            ToggleRow(L10n.Focus.autoStartBreaks, isOn: $viewModel.autoStartBreaks)
                            SettingsDivider()
                            ToggleRow(L10n.Focus.autoStartFocus, isOn: $viewModel.autoStartFocus)
                            SettingsDivider()
                            ToggleRow(L10n.Focus.sessionNotifications, isOn: $viewModel.sessionNotifications)
                        }
                        SettingsFootnote(L10n.Focus.settingsFootnote)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 34)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .presentationDetents([.large])
    }
}
