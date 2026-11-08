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
                            Text(L10n.DatePicker.noDateHint)
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
                        note(L10n.DatePicker.endBeforeStart, color: AppColors.danger)
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
        .overlay {
            // Контейнер всегда на месте; закрытая карточка не забирает касания,
            // даже пока доигрывает анимация исчезновения.
            ExactTimeCard(viewModel: viewModel)
                .allowsHitTesting(viewModel.isWheelOpen)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(16)
    }

    // MARK: - Шапка

    private var header: some View {
        @Bindable var viewModel = viewModel

        return HStack {
            circleButton("xmark", foreground: AppColors.label, background: AppColors.fillSecondary, action: onCancel)
                .accessibilityLabel(L10n.Common.cancel)
            Spacer()
            SegmentedPicker(
                options: [(.date, L10n.Common.date), (.period, L10n.Common.period)],
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
            .accessibilityLabel(L10n.Common.done)
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
                    symbol: "clock", title: L10n.Common.time, value: viewModel.timeValue,
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
                        .accessibilityLabel(L10n.DatePicker.removeTime)
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
                symbol: "bell", title: L10n.Common.reminder, value: viewModel.reminderTitle,
                isActive: viewModel.hasReminder, action: viewModel.toggleReminder
            ) { EmptyView() }
            if viewModel.isReminderExpanded {
                chips(viewModel.reminderOptions, select: viewModel.setReminder)
            }

            optionRow(
                symbol: "repeat", title: L10n.Common.repeat, value: viewModel.repeatTitle,
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
                title: L10n.Common.start, symbol: "clock", trailing: "",
                day: viewModel.startDayLabel, dayIsWarning: false,
                time: viewModel.startTimeLabel, timeIsWarning: false,
                dayStep: viewModel.shiftStartDay, timeStep: viewModel.shiftStartTime,
                openExact: { viewModel.openWheel(.start) }
            )
            periodBlock(
                title: L10n.Common.end, symbol: "circle", trailing: viewModel.durationLabel,
                day: viewModel.endDayLabel, dayIsWarning: viewModel.isEndDayBeforeStart,
                time: viewModel.endTimeLabel, timeIsWarning: viewModel.isInvalid,
                dayStep: viewModel.shiftEndDay, timeStep: viewModel.shiftEndTime,
                openExact: { viewModel.openWheel(.end) }
            )
        }
    }

    private func periodBlock(
        title: String, symbol: String, trailing: String,
        day: String, dayIsWarning: Bool, time: String, timeIsWarning: Bool,
        dayStep: @escaping (Int) -> Void, timeStep: @escaping (Int) -> Void,
        openExact: @escaping () -> Void
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
                stepField(label: day, isWarning: dayIsWarning, minus: "chevron.left", plus: "chevron.right",
                          onTapLabel: openExact) {
                    dayStep($0)
                }
                stepField(label: time, isWarning: timeIsWarning, minus: "minus", plus: "plus",
                          onTapLabel: openExact) {
                    timeStep($0 * 15)
                }
                .frame(width: 136)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { divider }
    }

    /// Поле со стрелками: стрелки шагают, нажатие на значение открывает точный выбор.
    private func stepField(
        label: String, isWarning: Bool, minus: String, plus: String,
        onTapLabel: @escaping () -> Void, step: @escaping (Int) -> Void
    ) -> some View {
        HStack(spacing: 0) {
            stepButton(minus) { step(-1) }
            Button(action: onTapLabel) {
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isWarning ? AppColors.danger : AppColors.label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(L10n.DatePicker.openExactTime)
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

// MARK: - Точное время

/// Плавающая карточка с колёсами «дата · часы · минуты» для начала или конца периода.
private struct ExactTimeCard: View {
    @Bindable var viewModel: DateTimePickerViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            if viewModel.isWheelOpen {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture(perform: viewModel.cancelWheel)
                    .transition(.opacity)

                card
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.25), value: viewModel.isWheelOpen)
    }

    private var card: some View {
            VStack(spacing: 12) {
                SegmentedPicker(
                    options: [(.start, L10n.Common.start), (.end, L10n.Common.end)],
                    selection: $viewModel.wheelEdge,
                    background: AppColors.fillSecondary
                )
                .frame(width: 220)

                wheels
                    .frame(height: 238)

                Text(viewModel.wheelSummary)
                    .font(AppFont.footnote)
                    .foregroundStyle(viewModel.isWheelInvalid ? AppColors.danger : AppColors.textSecondary)

                HStack(spacing: 10) {
                    Button(action: viewModel.cancelWheel) {
                        Text(L10n.Common.cancel)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(AppColors.label)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppColors.fillSecondary, in: Capsule())
                    }
                    Button(action: viewModel.applyWheel) {
                        Text(L10n.Common.apply)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppColors.accent, in: Capsule())
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 25, y: 20)
            .padding(.horizontal, 10)
            .padding(.bottom, 28)
            .ignoresSafeArea(edges: .bottom)
    }

    /// Три колеса в пропорциях макета 1.7 : 0.6 : 0.6 с общей полосой выбора по центру.
    private var wheels: some View {
        GeometryReader { proxy in
            let unit = (proxy.size.width - 12) / 2.9
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.fillSecondary)
                    .frame(height: WheelColumn.rowHeight)
                    .padding(.top, WheelColumn.rowHeight * 3)

                HStack(spacing: 4) {
                    WheelColumn(count: DateTimePickerViewModel.wheelDayCount, selection: $viewModel.wheelDayIndex,
                                label: viewModel.wheelDayLabel)
                        .frame(width: unit * 1.7)
                    WheelColumn(count: 24, selection: $viewModel.wheelHour) { String(format: "%02d", $0) }
                        .frame(width: unit * 0.6)
                    WheelColumn(count: 60, selection: $viewModel.wheelMinute) { String(format: "%02d", $0) }
                        .frame(width: unit * 0.6)
                }
                .padding(.horizontal, 2)
            }
        }
        .frame(height: WheelColumn.rowHeight * 7)
    }
}

/// Колесо выбора: строки по 34 pt, 7 видимых, прокрутка защёлкивается на строке,
/// выбранная — в центральной полосе. Края плавно гаснут, как в макете.
private struct WheelColumn: View {
    static let rowHeight: CGFloat = 34

    let count: Int
    @Binding var selection: Int
    let label: (Int) -> String

    /// Колесо крутит пользователь (палец или инерция). Программная прокрутка значение не меняет.
    @State private var isScrolling = false
    @State private var centeredIndex: Int?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(0..<count, id: \.self) { index in
                        row(index)
                            .id(index)
                            .onTapGesture {
                                withAnimation(.smooth(duration: 0.25)) { proxy.scrollTo(index, anchor: .center) }
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.vertical, Self.rowHeight * 3, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .onScrollGeometryChange(for: Int.self) { geometry in
                Int(((geometry.contentOffset.y + geometry.contentInsets.top) / Self.rowHeight).rounded())
            } action: { _, index in
                let index = min(max(index, 0), count - 1)
                centeredIndex = index
                if isScrolling, index != selection { selection = index }
            }
            .onScrollPhaseChange { _, phase in
                isScrolling = phase == .interacting || phase == .decelerating
                // Остановилось после жеста — фиксируем строку в центре.
                if phase == .idle, let centeredIndex, centeredIndex != selection { selection = centeredIndex }
            }
            // Внешние изменения (смена «Начало/Конец», сдвиг конца вслед за началом) — прокрутить к значению.
            .onChange(of: selection) { _, value in
                guard !isScrolling else { return }
                withAnimation(.smooth(duration: 0.25)) { proxy.scrollTo(value, anchor: .center) }
            }
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
            .sensoryFeedback(.selection, trigger: selection)
        }
        .mask {
            LinearGradient(
                stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.32),
                        .init(color: .black, location: 0.68), .init(color: .clear, location: 1)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    private func row(_ index: Int) -> some View {
        let isSelected = index == selection
        return Text(label(index))
            .font(.system(size: isSelected ? 21 : 19, weight: isSelected ? .medium : .regular))
            .monospacedDigit()
            .foregroundStyle(isSelected ? AppColors.label : AppColors.textQuaternary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .frame(height: Self.rowHeight)
            .contentShape(Rectangle())
    }
}
