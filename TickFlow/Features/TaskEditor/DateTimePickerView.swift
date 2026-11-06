import SwiftUI

/// Лист выбора даты, времени, периода, напоминания и повтора.
struct DateTimePickerView: View {
    @State private var viewModel: DateTimePickerViewModel
    let onCancel: () -> Void

    init(viewModel: DateTimePickerViewModel, onCancel: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onCancel = onCancel
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 12) {
                    if !viewModel.isPeriod {
                        presets
                        monthGrid
                        if !viewModel.hasDate {
                            Text("Без даты задача попадёт в раздел «Без даты».")
                                .font(.system(size: 14))
                                .foregroundStyle(AppColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                    }

                    if viewModel.hasDate {
                        optionsCard
                    }

                    if viewModel.isInvalid {
                        note("Конец раньше начала.", color: AppColors.danger)
                    }
                    if let conflict = viewModel.conflictText {
                        note(conflict, color: AppColors.warningText)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 34)
            }
        }
        .background(AppColors.surface)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(16)
    }

    // MARK: - Шапка

    private var header: some View {
        @Bindable var viewModel = viewModel

        return HStack {
            circleButton("xmark", foreground: AppColors.label, background: AppColors.fillSecondary, action: onCancel)
                .accessibilityLabel("Отмена")
            Spacer()
            SegmentedPicker(
                options: [(.date, "Дата"), (.period, "Период")],
                selection: $viewModel.tab,
                background: AppColors.fillSecondary
            )
            .frame(width: 200)
            Spacer()
            circleButton(
                "checkmark",
                foreground: .white,
                background: viewModel.canApply ? AppColors.accent : AppColors.doneDot,
                action: viewModel.apply
            )
            .disabled(!viewModel.canApply)
            .accessibilityLabel("Готово")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Пресеты и месяц

    private var presets: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
            ForEach(viewModel.presets) { preset in
                Button { viewModel.selectPreset(preset.id) } label: {
                    VStack(spacing: 6) {
                        presetIcon(preset.icon)
                            .frame(width: 24, height: 24)
                        Text(preset.title)
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.labelSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 2)
                    .background(
                        preset.isSelected ? AppColors.accentSoft : .clear,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func presetIcon(_ icon: DateTimePickerViewModel.PresetIcon) -> some View {
        switch icon {
        case .number(let text):
            ZStack {
                Image(systemName: "calendar")
                    .font(.system(size: 22))
                Text(text)
                    .font(.system(size: 8, weight: .bold))
                    .offset(y: 3)
            }
            .foregroundStyle(AppColors.accent)
        case .sun:
            Image(systemName: "sun.max")
                .font(.system(size: 21))
                .foregroundStyle(AppColors.accent)
        case .none:
            Image(systemName: "nosign")
                .font(.system(size: 21))
                .foregroundStyle(AppColors.accent)
        }
    }

    private var monthGrid: some View {
        VStack(spacing: 0) {
            HStack {
                chevronButton("chevron.left", action: viewModel.showPreviousMonth)
                Spacer()
                Text(viewModel.monthTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.label)
                Spacer()
                chevronButton("chevron.right", action: viewModel.showNextMonth)
            }
            .frame(height: 36)

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(viewModel.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textTertiary)
                        .frame(height: 24)
                }
                ForEach(viewModel.cells) { cell in
                    dayCell(cell)
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ cell: DateTimePickerViewModel.DayCell) -> some View {
        if let date = cell.date {
            Button { viewModel.select(day: date) } label: {
                Text(cell.label)
                    .font(.system(size: 16, weight: cell.isSelected || cell.isToday ? .semibold : .regular))
                    .foregroundStyle(
                        cell.isSelected ? Color.white
                            : cell.isToday ? AppColors.accent
                            : cell.isPast ? AppColors.textQuaternary : AppColors.label
                    )
                    .frame(width: 36, height: 36)
                    .background(cell.isSelected ? AppColors.accent : .clear, in: Circle())
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(height: 40)
        }
    }

    // MARK: - Время, напоминание, повтор

    private var optionsCard: some View {
        VStack(spacing: 0) {
            if viewModel.isPeriod {
                periodRows
            } else {
                optionRow(
                    symbol: "clock", title: "Время", value: viewModel.timeValue,
                    isActive: viewModel.hasTimeValue, action: viewModel.toggleTime
                ) {
                    if viewModel.hasTimeValue {
                        Button(action: viewModel.clearTime) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(AppColors.accent)
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Убрать время")
                    }
                }
                if viewModel.isTimeExpanded {
                    HStack {
                        Spacer()
                        StepperPill(
                            value: viewModel.startTimeLabel, minWidth: 76,
                            decrement: { viewModel.shiftStartTime(by: -15) },
                            increment: { viewModel.shiftStartTime(by: 15) }
                        )
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                    .overlay(alignment: .bottom) { divider }
                }
            }

            optionRow(
                symbol: "bell", title: "Напоминание", value: viewModel.reminderTitle,
                isActive: viewModel.hasReminder, action: viewModel.toggleReminder
            ) { EmptyView() }
            if viewModel.isReminderExpanded {
                chips(viewModel.reminderOptions, select: viewModel.setReminder)
            }

            optionRow(
                symbol: "repeat", title: "Повтор", value: viewModel.repeatTitle,
                isActive: viewModel.hasRepeat, showsDivider: viewModel.isRepeatExpanded, action: viewModel.toggleRepeat
            ) { EmptyView() }
            if viewModel.isRepeatExpanded {
                chips(viewModel.repeatOptions, select: viewModel.setRepeat, showsDivider: false)
            }
        }
        .background(Color(light: "#F7F7F9", dark: "#2C2C2E"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var periodRows: some View {
        VStack(spacing: 0) {
            periodBlock(
                title: "Начало", symbol: "clock", trailing: "",
                day: viewModel.startDayLabel, dayIsWarning: false,
                time: viewModel.startTimeLabel, timeIsWarning: false,
                dayStep: viewModel.shiftStartDay, timeStep: viewModel.shiftStartTime
            )
            periodBlock(
                title: "Конец", symbol: "circle", trailing: viewModel.durationLabel,
                day: viewModel.endDayLabel, dayIsWarning: viewModel.isEndDayBeforeStart,
                time: viewModel.endTimeLabel, timeIsWarning: viewModel.isInvalid,
                dayStep: viewModel.shiftEndDay, timeStep: viewModel.shiftEndTime
            )
        }
    }

    private func periodBlock(
        title: String, symbol: String, trailing: String,
        day: String, dayIsWarning: Bool, time: String, timeIsWarning: Bool,
        dayStep: @escaping (Int) -> Void, timeStep: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: symbol == "circle" ? 9 : 18, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 20)
                Text(title).font(AppFont.body).foregroundStyle(AppColors.label)
                Spacer()
                Text(trailing).font(AppFont.footnote).foregroundStyle(AppColors.textSecondary)
            }
            HStack(spacing: 8) {
                stepField(label: day, isWarning: dayIsWarning, minus: "chevron.left", plus: "chevron.right") {
                    dayStep($0)
                }
                stepField(label: time, isWarning: timeIsWarning, minus: "minus", plus: "plus") {
                    timeStep($0 * 15)
                }
                .frame(width: 136)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { divider }
    }

    private func stepField(label: String, isWarning: Bool, minus: String, plus: String, step: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 0) {
            stepButton(minus) { step(-1) }
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isWarning ? AppColors.danger : AppColors.label)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
            stepButton(plus) { step(1) }
        }
        .frame(height: 36)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(AppColors.separator, lineWidth: 0.5))
    }

    private func optionRow<Trailing: View>(
        symbol: String, title: String, value: String, isActive: Bool, showsDivider: Bool = true,
        action: @escaping () -> Void, @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(isActive ? AppColors.accent : AppColors.textTertiary)
                .frame(width: 22)
            Text(title).font(AppFont.body).foregroundStyle(AppColors.label)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: isActive ? .medium : .regular))
                .foregroundStyle(isActive ? AppColors.accent : AppColors.textTertiary)
            trailing()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .overlay(alignment: .bottom) { if showsDivider { divider } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private func chips<Value: Hashable>(
        _ options: [DateTimePickerViewModel.Option<Value>],
        select: @escaping (Value) -> Void,
        showsDivider: Bool = true
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(options) { option in
                    Chip(title: option.title, isSelected: option.isSelected, selectedColor: AppColors.accent) {
                        select(option.value)
                    }
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.top, 4)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { if showsDivider { divider } }
    }

    // MARK: - Мелочи

    private var divider: some View {
        Rectangle().fill(AppColors.separator).frame(height: 0.5)
    }

    private func note(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private func circleButton(_ symbol: String, foreground: Color, background: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(foreground)
                .frame(width: 40, height: 40)
                .background(background, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func chevronButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.textTertiary)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 34, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
