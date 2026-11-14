import SwiftUI

/// Таймлайн на 1, 3 или 7 дней. Рисует готовые элементы из view model,
/// а смещения пальца передаёт ей как есть — правила переноса живут там.
struct TimeGridView: View {
    let viewModel: CalendarViewModel

    private let rootSpace = "timeGridRoot"
    private let topPadding: CGFloat = 10
    private let barHeight: CGFloat = 21
    private let barSpacing: CGFloat = 24

    @State private var width: CGFloat = 0
    @State private var scrollPosition = ScrollPosition()
    @State private var viewport = Viewport()
    @State private var gridTop: CGFloat = 0
    /// Состояние жеста: где начался и сколько была прокручена шкала.
    @State private var gesture: GestureTrack?

    private struct Viewport: Equatable {
        var offset: CGFloat = 0
        var height: CGFloat = 0
        var maxOffset: CGFloat = 0
    }

    private struct GestureTrack {
        let start: CGPoint
        let startOffset: CGFloat
        /// Карточка на шкале — только для неё работает автопрокрутка.
        let isOnGrid: Bool
        var location: CGPoint
    }

    private var geometry: TimelineGeometry { viewModel.geometry }
    private var columnWidth: CGFloat {
        max(0, (width - geometry.gutterWidth - 4) / CGFloat(geometry.dayCount))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isDay {
                dayStrip
            } else {
                columnHeaders
            }
            allDayRow
            Rectangle().fill(AppColors.separator).frame(height: 0.5)
            TimelineView(.periodic(from: .now, by: 30)) { context in
                scrollArea(now: context.date)
            }
        }
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
        .coordinateSpace(.named(rootSpace))
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.isDragging) { _, new in new }
        .sensoryFeedback(.selection, trigger: viewModel.dragStepKey)
    }

    // MARK: - Заголовки

    private var dayStrip: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(viewModel.dayStrip) { day in
                    Button { viewModel.select(day.id) } label: {
                        VStack(spacing: 4) {
                            Text(day.weekday)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppColors.textTertiary)
                            Text(day.number)
                                .font(.system(size: 16, weight: day.isSelected || day.isToday ? .semibold : .regular))
                                .foregroundStyle(stripNumberColor(day))
                                .frame(width: 34, height: 34)
                                .background {
                                    if day.isSelected {
                                        Circle().fill(day.isToday ? AppColors.accent : AppColors.inverse)
                                    }
                                }
                            Circle()
                                .fill(day.hasTasks ? AppColors.textQuaternary : .clear)
                                .frame(width: 4, height: 4)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(viewModel.dayLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)
                .padding(.bottom, 6)
        }
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded {
            viewModel.swipe(dx: $0.translation.width, dy: $0.translation.height)
        })
    }

    private func stripNumberColor(_ day: CalendarItems.DayHeader) -> Color {
        if day.isSelected { return .white }
        return day.isToday ? AppColors.accent : AppColors.label
    }

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: geometry.gutterWidth)
            ForEach(viewModel.columnHeaders) { day in
                Button { viewModel.openDay(day.id) } label: {
                    VStack(spacing: 3) {
                        Text(day.weekday)
                            .font(.system(size: geometry.isNarrow ? 10.5 : 11, weight: .semibold))
                            .foregroundStyle(day.isToday ? AppColors.accent : AppColors.textTertiary)
                        Text(day.number)
                            .font(.system(size: geometry.isNarrow ? 15 : 17, weight: .semibold))
                            .foregroundStyle(day.isToday ? .white : AppColors.label)
                            .frame(width: 28, height: 28)
                            .background { if day.isToday { Circle().fill(AppColors.accent) } }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Color.clear.frame(width: 4)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.bottom, 6)
        .contentShape(Rectangle())
        .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded {
            viewModel.swipe(dx: $0.translation.width, dy: $0.translation.height)
        })
    }

    // MARK: - Весь день

    @ViewBuilder
    private var allDayRow: some View {
        let bars = viewModel.bars
        if !bars.isEmpty {
            ZStack(alignment: .topLeading) {
                Text(L10n.Common.allDayShort)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(AppColors.textTertiary)
                    .multilineTextAlignment(.trailing)
                    .frame(width: geometry.gutterWidth - 6, alignment: .trailing)
                ForEach(bars) { bar in
                    barView(bar)
                }
            }
            .frame(height: CGFloat(viewModel.allDayLaneCount - 1) * barSpacing + barHeight + 8, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
            .animation(.snappy(duration: 0.2), value: viewModel.dragStepKey)
        }
    }

    private func barView(_ bar: CalendarItems.Bar) -> some View {
        let style = CategoryStyle(hex: bar.colorHex)
        let x = geometry.gutterWidth + CGFloat(bar.first) * columnWidth + 1
        let barWidth = max(0, CGFloat(bar.last - bar.first + 1) * columnWidth - 3)

        return HStack(spacing: 4) {
            Text(bar.title)
                .font(.system(size: geometry.isNarrow ? 10.5 : 12, weight: .semibold))
                .lineLimit(1)
                .strikethrough(bar.isCompleted)
            Spacer(minLength: 0)
            if bar.isMultiDay, !geometry.isNarrow {
                Capsule().fill(style.foreground.opacity(0.35)).frame(width: 3, height: 11)
            }
        }
        .foregroundStyle(bar.isCompleted ? AppColors.completedText : style.foreground)
        .padding(.horizontal, 6)
        .frame(width: barWidth, height: barHeight)
        .background(bar.isCompleted ? AppColors.completedFill : style.background,
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(style.tint.opacity(bar.isDragging ? 0.6 : 0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(bar.isDragging ? 0.18 : 0), radius: 6, y: 3)
        .offset(x: x, y: CGFloat(bar.lane) * barSpacing)
        .onTapGesture { viewModel.open(bar.id) }
        .gesture(recognizer(isOnGrid: false) { location in
            let localX = location.x - x
            let mode: CalendarViewModel.DragMode = if localX < 16 {
                .extendStart
            } else if localX > barWidth - 16 {
                .extendEnd
            } else {
                .shiftDays
            }
            viewModel.beginDrag(bar.id, mode: mode)
        })
    }

    // MARK: - Шкала

    private func scrollArea(now: Date) -> some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                hourLines(now: now)
                todayTint
                tapLayer
                if let ghost = viewModel.ghost {
                    ghostView(ghost)
                }
                let narrowed = viewModel.sessionDayIndexes
                ForEach(viewModel.cards) { card in
                    cardView(card, inset: narrowed.contains(card.dayIndex) ? geometry.sessionLaneWidth : 0)
                }
                ForEach(viewModel.sessions) { session in
                    sessionView(session)
                }
                if let live = viewModel.liveDayIndex {
                    LiveSessionBlock(geometry: geometry, columnWidth: columnWidth, dayIndex: live,
                                     minuteOf: viewModel.minute(of:), onTap: viewModel.openLiveSession)
                }
                if let line = viewModel.nowLine(at: now) {
                    nowLineView(line)
                }
            }
            .frame(height: geometry.contentHeight, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.top, topPadding)
            .padding(.bottom, 110)
            .animation(.snappy(duration: 0.2), value: viewModel.dragStepKey)
        }
        .scrollPosition($scrollPosition)
        .scrollDisabled(viewModel.isDragging)
        .onScrollGeometryChange(for: Viewport.self) { geometry in
            let height = geometry.containerSize.height - geometry.contentInsets.bottom
            return Viewport(
                offset: geometry.contentOffset.y,
                height: height,
                maxOffset: max(geometry.contentSize.height - height, 0)
            )
        } action: { _, value in
            viewport = value
        }
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(rootSpace)).minY } action: { gridTop = $0 }
        .overlay(alignment: .top) { hud }
        .task(id: viewModel.isDragging) { await autoScroll() }
        .onAppear { scrollToStart() }
        .onChange(of: viewModel.mode) { scrollToStart() }
    }

    private func scrollToStart() {
        scrollPosition.scrollTo(y: geometry.y(forMinute: viewModel.initialScrollMinute))
    }

    private func hourLines(now: Date) -> some View {
        ForEach(viewModel.hourLabels(now: now)) { label in
            let y = geometry.y(forMinute: label.hour * 60)
            ZStack(alignment: .topLeading) {
                Text(label.text)
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(AppColors.textTertiary)
                    .frame(width: geometry.gutterWidth - 8, alignment: .trailing)
                    .offset(y: y - 7)
                Rectangle()
                    .fill(AppColors.hairline)
                    .frame(height: 1)
                    .padding(.leading, geometry.gutterWidth)
                    .offset(y: y)
            }
        }
    }

    @ViewBuilder
    private var todayTint: some View {
        if !viewModel.isDay {
            ForEach(0..<geometry.dayCount, id: \.self) { index in
                if viewModel.isToday(index) {
                    Rectangle()
                        .fill(AppColors.accent.opacity(0.035))
                        .frame(width: columnWidth, height: geometry.contentHeight)
                        .offset(x: geometry.gutterWidth + CGFloat(index) * columnWidth)
                }
            }
        }
    }

    /// Нажатие на свободное место создаёт задачу на это время.
    private var tapLayer: some View {
        Color.clear
            .frame(width: columnWidth * CGFloat(geometry.dayCount), height: geometry.contentHeight)
            .contentShape(Rectangle())
            .onTapGesture { location in
                guard columnWidth > 0 else { return }
                viewModel.beginCreatingTask(dayIndex: Int(location.x / columnWidth), y: location.y)
            }
            .offset(x: geometry.gutterWidth)
    }

    private func frame(dayIndex: Int, start: Int, end: Int, lane: Int = 0, laneCount: Int = 1, inset: CGFloat = 0) -> CGRect {
        let laneWidth = max(0, columnWidth - inset) / CGFloat(max(1, laneCount))
        return CGRect(
            x: geometry.gutterWidth + CGFloat(dayIndex) * columnWidth + CGFloat(lane) * laneWidth + 1,
            y: geometry.y(forMinute: start) + 1,
            width: max(0, laneWidth - 2),
            height: max(16, geometry.height(minutes: end - start) - 2)
        )
    }

    private func ghostView(_ ghost: CalendarItems.Ghost) -> some View {
        let rect = frame(dayIndex: ghost.dayIndex, start: ghost.startMinute, end: ghost.endMinute)
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .strokeBorder(Color(hex: ghost.colorHex).opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .allowsHitTesting(false)
    }

    private func sessionView(_ session: CalendarItems.Session) -> some View {
        let rect = SessionBlockFrame.rect(geometry: geometry, columnWidth: columnWidth, dayIndex: session.dayIndex,
                                          start: session.startMinute, end: session.endMinute)
        return SessionBlockView(
            title: session.title, detail: session.detail, colorHex: session.colorHex,
            isInterrupted: session.isInterrupted, isWide: geometry.showsSessionLabels, height: rect.height
        )
        .frame(width: rect.width, height: rect.height)
        .contentShape(Rectangle())
        .onTapGesture { viewModel.openSession(session.id) }
        .offset(x: rect.minX, y: rect.minY)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(session.title + ", " + session.detail)
        .accessibilityAddTraits(.isButton)
    }

    private func cardView(_ card: CalendarItems.Card, inset: CGFloat = 0) -> some View {
        let rect = frame(dayIndex: card.dayIndex, start: card.startMinute, end: card.endMinute,
                         lane: card.lane, laneCount: card.laneCount, inset: inset)
        let style = CategoryStyle(hex: card.colorHex)
        let narrow = geometry.isNarrow
        let showsTime = rect.height >= (narrow ? 46 : 34)
        let foreground = card.isCompleted ? AppColors.completedText : style.foreground
        let hasBottomHandle = !card.isCompleted && rect.height >= 28
        let hasTopHandle = !card.isCompleted && viewModel.isDay && rect.height >= 40

        return VStack(alignment: .leading, spacing: 1) {
            Text(card.title)
                .font(.system(size: narrow ? 10.5 : 13, weight: .semibold))
                .strikethrough(card.isCompleted)
                .lineLimit(rect.height >= 50 ? 2 : 1)
            if showsTime {
                Text(card.time)
                    .font(.system(size: narrow ? 9.5 : 11.5, weight: .medium))
                    .monospacedDigit()
                    .opacity(0.8)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, narrow ? 3 : 6)
        .padding(.vertical, rect.height >= 24 ? 4 : 1)
        .frame(width: rect.width, height: rect.height, alignment: .topLeading)
        .background(card.isCompleted ? AppColors.completedFill : style.background,
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(card.isHighlighted ? style.tint : style.tint.opacity(0.18),
                              lineWidth: card.isHighlighted ? 2 : 1)
        )
        .overlay(alignment: .bottom) {
            if hasBottomHandle {
                Capsule().fill(foreground.opacity(0.3)).frame(width: 16, height: 3).padding(.bottom, 3)
            }
        }
        .overlay(alignment: .top) {
            if hasTopHandle {
                Capsule().fill(foreground.opacity(0.3)).frame(width: 16, height: 3).padding(.top, 3)
            }
        }
        .overlay(alignment: .topTrailing) {
            if card.hasConflict {
                Text("!")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 14, height: 14)
                    .background(AppColors.warning, in: Circle())
                    .padding(2)
            }
        }
        .scaleEffect(card.isDragging ? 1.02 : 1)
        .shadow(color: .black.opacity(card.isDragging ? 0.2 : 0), radius: 8, y: 4)
        .offset(x: rect.minX, y: rect.minY)
        .zIndex(card.isDragging ? 1 : 0)
        .onTapGesture { viewModel.open(card.id) }
        .gesture(recognizer(isOnGrid: true) { location in
            // Точка внутри карточки, чтобы понять, за какой край её взяли.
            let y = location.y - gridTop - topPadding + viewport.offset - rect.minY
            let mode: CalendarViewModel.DragMode = if hasBottomHandle, y > rect.height - 12 {
                .resizeBottom
            } else if hasTopHandle, y < 12 {
                .resizeTop
            } else {
                .move
            }
            viewModel.beginDrag(card.id, mode: mode)
        })
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private func nowLineView(_ line: CalendarItems.NowLine) -> some View {
        let y = geometry.y(forMinute: line.minute)
        let x = geometry.gutterWidth + CGFloat(line.dayIndex) * columnWidth
        return ZStack(alignment: .topLeading) {
            Text(line.label)
                .font(.system(size: 10.5, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(AppColors.nowLine)
                .frame(width: geometry.gutterWidth - 8, alignment: .trailing)
                .offset(y: y - 7)
            Rectangle()
                .fill(AppColors.nowLine)
                .frame(width: columnWidth, height: 1.5)
                .offset(x: x, y: y - 0.75)
            Circle()
                .fill(AppColors.nowLine)
                .frame(width: 8, height: 8)
                .offset(x: x - 4, y: y - 4)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var hud: some View {
        if let text = viewModel.hud {
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(AppColors.toastBackground, in: Capsule())
                .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
                .padding(.top, 8)
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    // MARK: - Перетаскивание

    /// Удержание 0,3 с, затем перенос. Смещение пальца с поправкой на автопрокрутку уходит во view model.
    private func recognizer(isOnGrid: Bool, onBegan: @escaping (CGPoint) -> Void) -> TaskDragRecognizer {
        TaskDragRecognizer(coordinateSpace: rootSpace) { location in
            gesture = GestureTrack(start: location, startOffset: viewport.offset, isOnGrid: isOnGrid, location: location)
            onBegan(location)
        } onChanged: { location in
            gesture?.location = location
            sendDrag()
        } onEnded: { isCancelled in
            gesture = nil
            if isCancelled { viewModel.cancelDrag() } else { viewModel.endDrag() }
        }
    }

    private func sendDrag() {
        guard let gesture else { return }
        let scrolled = gesture.isOnGrid ? viewport.offset - gesture.startOffset : 0
        viewModel.updateDrag(
            dx: gesture.location.x - gesture.start.x,
            dy: gesture.location.y - gesture.start.y + scrolled,
            columnWidth: columnWidth
        )
    }

    /// Пока палец у края шкалы, прокручиваем её, чтобы дотянуться до любого часа.
    private func autoScroll() async {
        let edge: CGFloat = 56
        let step: CGFloat = 4
        while viewModel.isDragging, !Task.isCancelled {
            if let gesture, gesture.isOnGrid, viewModel.hud != nil {
                let y = gesture.location.y - gridTop
                var offset = viewport.offset
                if y < edge {
                    offset -= step
                } else if y > viewport.height - edge {
                    offset += step
                }
                offset = min(max(offset, 0), viewport.maxOffset)
                if offset != viewport.offset {
                    scrollPosition.scrollTo(y: offset)
                    viewport.offset = offset
                    sendDrag()
                }
            }
            try? await Task.sleep(for: .milliseconds(16))
        }
    }
}
