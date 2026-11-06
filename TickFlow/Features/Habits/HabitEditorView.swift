import SwiftUI

struct HabitEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: HabitEditorViewModel
    @FocusState private var isNameFocused: Bool

    init(viewModel: HabitEditorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 14) {
                    if !viewModel.suggestions.isEmpty { suggestions }
                    nameCard
                    appearanceCard
                    trackingCard
                    reminderCard
                    if !viewModel.isNew {
                        Button("Удалить привычку", role: .destructive, action: viewModel.requestDelete)
                            .font(.system(size: 17))
                            .foregroundStyle(AppColors.danger)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(AppColors.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(14)
        .interactiveDismissDisabled(!viewModel.name.isEmpty)
        .confirmationDialog(
            "Удалить «\(viewModel.name)»?",
            isPresented: $viewModel.isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive, action: viewModel.confirmDelete)
        } message: {
            Text("История отметок тоже будет удалена.")
        }
        .onChange(of: viewModel.isFinished) { _, finished in
            if finished { dismiss() }
        }
        .onAppear { if viewModel.isNew { isNameFocused = true } }
    }

    private var header: some View {
        HStack {
            Button("Отмена") { dismiss() }
            Spacer()
            Text(viewModel.title)
                .font(AppFont.headline)
                .foregroundStyle(AppColors.label)
            Spacer()
            Button(viewModel.saveTitle, action: viewModel.save)
                .fontWeight(.semibold)
                .foregroundStyle(viewModel.canSave ? AppColors.accent : AppColors.chevron)
                .disabled(!viewModel.canSave)
        }
        .font(.system(size: 17))
        .foregroundStyle(AppColors.accent)
        .buttonStyle(.plain)
        .frame(height: 48)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Подсказки")
                .font(AppFont.footnote)
                .foregroundStyle(AppColors.textSecondary)
                .padding(.horizontal, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(viewModel.suggestions) { suggestion in
                        Button(suggestion.name) { viewModel.apply(suggestion) }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.label)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(AppColors.surface, in: Capsule())
                            .buttonStyle(.plain)
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private var nameCard: some View {
        @Bindable var viewModel = viewModel

        return HStack(spacing: 12) {
            HabitIcon(symbol: viewModel.symbolName, colorHex: viewModel.colorHex, size: 42)
            TextField("Название привычки", text: $viewModel.name)
                .font(.system(size: 20, weight: .semibold))
                .focused($isNameFocused)
                .submitLabel(.done)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var appearanceCard: some View {
        let tint = Color(hex: viewModel.colorHex)

        return EditorCard {
            EditorSection(title: "Иконка") {
                HStack {
                    ForEach(viewModel.symbols, id: \.self) { symbol in
                        let isSelected = symbol == viewModel.symbolName
                        Button { viewModel.selectSymbol(symbol) } label: {
                            Image(systemName: symbol)
                                .font(.system(size: 18))
                                .foregroundStyle(isSelected ? tint : AppColors.textTertiary)
                                .frame(width: 36, height: 36)
                                .background(isSelected ? tint.opacity(0.12) : .clear,
                                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            EditorDivider()
            EditorSection(title: "Цвет") {
                HStack(spacing: 14) {
                    ForEach(viewModel.colors, id: \.self) { hex in
                        let isSelected = hex == viewModel.colorHex
                        Button { viewModel.selectColor(hex) } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 28, height: 28)
                                .padding(3)
                                .overlay(Circle().stroke(isSelected ? Color(hex: hex) : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var trackingCard: some View {
        @Bindable var viewModel = viewModel
        let tint = Color(hex: viewModel.colorHex)

        return EditorCard {
            EditorSection(title: "Отслеживание") {
                SegmentedPicker(options: viewModel.kindOptions, selection: $viewModel.kindSelection,
                                background: AppColors.fillSecondary)
            }
            if viewModel.isMeasurable {
                EditorDivider()
                HStack {
                    Text("Цель на день").font(AppFont.body).foregroundStyle(AppColors.label)
                    Spacer()
                    StepperPill(value: viewModel.targetLabel, decrement: viewModel.decrementTarget,
                                increment: viewModel.incrementTarget)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            if viewModel.isAmount {
                EditorDivider()
                EditorSection(title: "Единица") {
                    HStack(spacing: 6) {
                        ForEach(HabitEditorViewModel.units, id: \.self) { unit in
                            Chip(title: unit, isSelected: unit == viewModel.unit) { viewModel.selectUnit(unit) }
                        }
                    }
                }
            }
            EditorDivider()
            EditorSection(title: "Частота") {
                SegmentedPicker(options: viewModel.frequencyOptions, selection: $viewModel.frequency,
                                background: AppColors.fillSecondary)
                if viewModel.isSpecificDays {
                    HStack {
                        ForEach(viewModel.weekdayOptions) { day in
                            Button { viewModel.toggleWeekday(day.id) } label: {
                                Text(day.letter)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(day.isOn ? .white : AppColors.textSecondary)
                                    .frame(width: 36, height: 36)
                                    .background(day.isOn ? tint : AppColors.fillSecondary, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                if viewModel.isWeeklyGoal {
                    HStack {
                        Text("Раз в неделю").font(AppFont.subheadline).foregroundStyle(AppColors.label)
                        Spacer()
                        StepperPill(value: viewModel.timesPerWeekLabel, minWidth: 40,
                                    decrement: viewModel.decrementTimesPerWeek,
                                    increment: viewModel.incrementTimesPerWeek)
                    }
                }
            }
        }
    }

    private var reminderCard: some View {
        @Bindable var viewModel = viewModel

        return EditorCard {
            Toggle("Напоминание", isOn: $viewModel.reminderEnabled)
                .font(AppFont.body)
                .tint(AppColors.accent)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .padding(.vertical, 2)
            if viewModel.reminderEnabled {
                HStack {
                    Text("Время").font(AppFont.subheadline).foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    StepperPill(value: viewModel.reminderLabel, minWidth: 80,
                                decrement: viewModel.decrementReminder,
                                increment: viewModel.incrementReminder)
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .padding(.bottom, 12)
            }
            EditorDivider()
            HStack {
                Text("Начало").foregroundStyle(AppColors.label)
                Spacer()
                Text(viewModel.startLabel).foregroundStyle(AppColors.textSecondary)
            }
            .font(AppFont.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

private struct EditorCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct EditorSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(AppFont.footnote).foregroundStyle(AppColors.textSecondary)
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct EditorDivider: View {
    var body: some View {
        Divider().overlay(AppColors.separator).padding(.leading, 16)
    }
}
