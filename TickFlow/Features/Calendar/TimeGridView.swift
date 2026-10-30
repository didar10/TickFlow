import SwiftUI

/// Таймлайн на один или несколько дней: задачи — цветные блоки на шкале часов.
struct TimeGridView: View {
    let days: [Date]
    let tasks: [TaskItem]
    let onSelect: (TaskItem) -> Void
    let onToggle: (TaskItem) -> Void
    let onDelete: (TaskItem) -> Void
    /// Нажатие на свободное место: создать задачу на это время.
    let onCreate: (Date) -> Void
    /// Задачу перетащили на новое время начала.
    let onMove: (TaskItem, Date) -> Void
    /// Длительность изменили, потянув за нижний край блока.
    let onResize: (TaskItem, Int) -> Void
    /// Свайп по шапке: -1 назад, 1 вперёд.
    let onShift: (Int) -> Void

    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 64
    private let gutterWidth: CGFloat = 40
    private let allDayRowHeight: CGFloat = 26
    private let topPadding: CGFloat = 10
    private let snapMinutes = 15
    private let minimumDurationMinutes = 15
    private let rootSpace = "timeGridRoot"
    /// Блок задачи без времени появляется чуть выше пальца.
    private let allDayGrabOffset: CGFloat = 12

    @State private var drag: TaskDrag?
    @State private var menuTask: TaskItem?
    @State private var scrollPosition = ScrollPosition()
    @State private var viewport = ScrollViewport()
    @State private var columnsWidth: CGFloat = 0
    @State private var gridTop: CGFloat = 0

    /// Текущее перетаскивание. Точки заданы относительно верха видимой области шкалы,
    /// поэтому над шкалой (в полосе «Весь день») `y` отрицательный.
    private struct TaskDrag {
        let task: TaskItem
        /// Захват за нижний край меняет длительность, за остальной блок — время.
        let isResizing: Bool
        let startMinute: Int
        let startLocation: CGPoint
        /// Расстояние от верха блока (при переносе) или его низа (при растягивании) до пальца,
        /// чтобы блок не прыгал под палец.
        let grabOffset: CGFloat
        var location: CGPoint
        var hasMoved = false
    }

    private struct ScrollViewport: Equatable {
        var offset: CGFloat = 0
        var height: CGFloat = 0
        var maxOffset: CGFloat = 0
    }

    /// Где окажется задача, если отпустить её сейчас.
    private struct DropTarget: Equatable {
        let dayIndex: Int
        let minute: Int
        let duration: Int
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 30).onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        onShift(value.translation.width < 0 ? 1 : -1)
                    }
                )

            allDayStrip

            Rectangle()
                .fill(AppColors.hairline)
                .frame(height: 1)

            ScrollViewReader { proxy in
                ScrollView {
                    HStack(alignment: .top, spacing: 0) {
                        hourLabels
                        HStack(spacing: 0) {
                            ForEach(days, id: \.self) { day in
                                dayColumn(day)
                            }
                        }
                        .onGeometryChange(for: CGFloat.self, of: \.size.width) { columnsWidth = $0 }
                        .overlay(alignment: .topLeading) { dragPreview }
                    }
                    .padding(.top, topPadding)
                    .padding(.trailing, 4)
                    .padding(.bottom, 96)
                }
                .onGeometryChange(for: CGFloat.self) {
                    $0.frame(in: .named(rootSpace)).minY
                } action: {
                    gridTop = $0
                }
                .scrollPosition($scrollPosition)
                .scrollDisabled(drag != nil)
                .onScrollGeometryChange(for: ScrollViewport.self) { geometry in
                    let height = geometry.containerSize.height - geometry.contentInsets.bottom
                    return ScrollViewport(
                        offset: geometry.contentOffset.y,
                        height: height,
                        maxOffset: max(geometry.contentSize.height - height, 0)
                    )
                } action: { _, value in
                    viewport = value
                }
                .task(id: drag != nil) {
                    await autoScrollWhileDragging()
                }
                .onAppear {
                    let hour = calendar.component(.hour, from: .now)
                    // Ночью остаёмся в начале дня, иначе обрежется подпись "00".
                    if hour > 1 {
                        proxy.scrollTo(hour - 1, anchor: .top)
                    }
                }
            }
        }
        .coordinateSpace(.named(rootSpace))
        .sensoryFeedback(.impact, trigger: drag?.task.id)
        .confirmationDialog(
            menuTask?.title ?? "",
            isPresented: Binding { menuTask != nil } set: { if !$0 { menuTask = nil } },
            titleVisibility: .visible,
            presenting: menuTask
        ) { task in
            taskMenu(task)
        }
    }

    // MARK: - Шапка

    private var header: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: gutterWidth, height: 1)
            ForEach(days, id: \.self) { day in
                let isToday = calendar.isDateInToday(day)
                VStack(spacing: 4) {
                    Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(day.formatted(.dateTime.day()))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isToday ? Color.white : .primary)
                        .frame(width: 30, height: 30)
                        .background {
                            if isToday {
                                Circle().fill(Color.accentColor)
                            }
                        }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.trailing, 4)
        .padding(.bottom, 6)
    }

    // MARK: - Задачи без времени

    @ViewBuilder
    private var allDayStrip: some View {
        let rows = days.map(allDayTasks(on:)).map(\.count).max() ?? 0
        if rows > 0 {
            ScrollView {
                HStack(alignment: .top, spacing: 0) {
                    Text("Весь\nдень")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(width: gutterWidth)

                    ForEach(days, id: \.self) { day in
                        VStack(spacing: 2) {
                            ForEach(allDayTasks(on: day)) { task in
                                allDayChip(task)
                            }
                        }
                        .padding(.horizontal, 1)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.trailing, 4)
            }
            .frame(height: min(CGFloat(rows), 3) * (allDayRowHeight + 2))
            .padding(.bottom, 4)
        }
    }

    private func allDayChip(_ task: TaskItem) -> some View {
        Text(task.title)
            .font(.caption)
            .strikethrough(task.isCompleted)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: allDayRowHeight, alignment: .leading)
            .background(blockFill(task), in: .rect(cornerRadius: 6))
            .opacity(task.isCompleted ? 0.5 : 1)
            .opacity(drag?.task.id == task.id ? 0.3 : 1)
            .contentShape(.rect(cornerRadius: 6))
            .onTapGesture { onSelect(task) }
            .gesture(allDayDragRecognizer(for: task))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - Сетка

    private var hourLabels: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                Text(String(format: "%02d", hour))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .offset(y: -7)
                    .frame(width: gutterWidth, height: hourHeight, alignment: .top)
                    .id(hour)
            }
        }
    }

    private func dayColumn(_ day: Date) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                hourLines
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        create(on: day, atY: location.y)
                    }

                ForEach(TimeGridLayout.place(timedTasks(on: day))) { placed in
                    block(placed, columnWidth: geometry.size.width)
                }

                if calendar.isDateInToday(day) {
                    nowIndicator
                }
            }
        }
        .frame(height: hourHeight * 24)
    }

    private var hourLines: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { _ in
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(AppColors.hairline)
                        .frame(height: 0.5)
                    Spacer(minLength: 0)
                }
                .frame(height: hourHeight)
            }
        }
    }

    private func block(_ placed: PlacedTask, columnWidth: CGFloat) -> some View {
        let task = placed.task
        let width = columnWidth / CGFloat(placed.columnCount)
        let height = CGFloat(placed.endMinute - placed.startMinute) / 60 * hourHeight
        let isCompact = days.count == 7

        // Не Button: кнопка перехватывает касание, и удержание для перетаскивания не срабатывает.
        return VStack(alignment: .leading, spacing: 2) {
            Text(task.title)
                .font(isCompact ? .caption2 : .footnote)
                .strikethrough(task.isCompleted)

            if !isCompact, height >= 44, let range = DateFormatting.timeRange(for: task) {
                Text(range)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, isCompact ? 3 : 6)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(blockFill(task), in: .rect(cornerRadius: 6))
        .clipShape(.rect(cornerRadius: 6))
        .opacity(task.isCompleted ? 0.5 : 1)
        .overlay(alignment: .bottom) {
            if height >= 36 {
                Capsule()
                    .fill(.primary.opacity(0.35))
                    .frame(width: 20, height: 3)
                    .padding(.bottom, 3)
            }
        }
        .opacity(drag?.task.id == task.id ? 0.3 : 1)
        .contentShape(.rect(cornerRadius: 6))
        .onTapGesture { onSelect(task) }
        .gesture(dragRecognizer(for: placed))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .frame(width: max(width - 2, 0), height: max(height - 2, 0))
        .offset(
            x: CGFloat(placed.column) * width + 1,
            y: CGFloat(placed.startMinute) / 60 * hourHeight + 1
        )
    }

    // MARK: - Перетаскивание

    private func dragRecognizer(for placed: PlacedTask) -> TaskDragRecognizer {
        let task = placed.task
        return TaskDragRecognizer(coordinateSpace: rootSpace) { rootLocation in
            let location = gridPoint(rootLocation)
            let blockTop = CGFloat(placed.startMinute) / 60 * hourHeight + topPadding - viewport.offset
            let height = CGFloat(placed.endMinute - placed.startMinute) / 60 * hourHeight
            let blockBottom = blockTop + height
            let isResizing = location.y > blockBottom - min(18, height * 0.35)
            drag = TaskDrag(
                task: task,
                isResizing: isResizing,
                startMinute: placed.startMinute,
                startLocation: location,
                grabOffset: location.y - (isResizing ? blockBottom : blockTop),
                location: location
            )
        } onChanged: { rootLocation in
            updateDrag(to: gridPoint(rootLocation))
        } onEnded: { isCancelled in
            finishDrag(isCancelled: isCancelled)
        }
    }

    /// Задача без времени получает время там, где её отпустят на шкале.
    private func allDayDragRecognizer(for task: TaskItem) -> TaskDragRecognizer {
        TaskDragRecognizer(coordinateSpace: rootSpace) { rootLocation in
            let location = gridPoint(rootLocation)
            drag = TaskDrag(
                task: task,
                isResizing: false,
                startMinute: 0,
                startLocation: location,
                grabOffset: allDayGrabOffset,
                location: location
            )
        } onChanged: { rootLocation in
            updateDrag(to: gridPoint(rootLocation))
        } onEnded: { isCancelled in
            finishDrag(isCancelled: isCancelled)
        }
    }

    private func gridPoint(_ rootLocation: CGPoint) -> CGPoint {
        CGPoint(x: rootLocation.x, y: rootLocation.y - gridTop)
    }

    private func updateDrag(to location: CGPoint) {
        drag?.location = location
        if let start = drag?.startLocation, hypot(location.x - start.x, location.y - start.y) > 8 {
            drag?.hasMoved = true
        }
    }

    /// Палец ещё над шкалой: задача без времени остаётся на месте.
    private func isAboveGrid(_ drag: TaskDrag) -> Bool {
        !drag.task.hasTime && drag.location.y < 0
    }

    private func finishDrag(isCancelled: Bool) {
        defer { drag = nil }
        guard !isCancelled, let drag else { return }
        // Удержание без движения открывает действия с задачей.
        guard drag.hasMoved else {
            menuTask = drag.task
            return
        }
        guard !isAboveGrid(drag), let target = dropTarget(for: drag) else { return }
        if drag.isResizing {
            if target.duration != drag.task.durationMinutes {
                onResize(drag.task, target.duration)
            }
            return
        }
        guard let start = calendar.date(
                byAdding: .minute,
                value: target.minute,
                to: calendar.startOfDay(for: days[target.dayIndex])
              ),
              start != drag.task.dueDate || !drag.task.hasTime
        else { return }
        onMove(drag.task, start)
    }

    private func dropTarget(for drag: TaskDrag) -> DropTarget? {
        guard columnsWidth > 0, !days.isEmpty else { return nil }

        if drag.isResizing {
            guard let due = drag.task.dueDate,
                  let dayIndex = days.firstIndex(where: { calendar.isDate($0, inSameDayAs: due) })
            else { return nil }
            let end = snappedMinute(atY: drag.location.y - drag.grabOffset)
            let clampedEnd = min(max(end, drag.startMinute + minimumDurationMinutes), TimeGridLayout.minutesInDay)
            return DropTarget(dayIndex: dayIndex, minute: drag.startMinute, duration: clampedEnd - drag.startMinute)
        }

        let columnWidth = columnsWidth / CGFloat(days.count)
        let day = Int((drag.location.x - gutterWidth) / columnWidth)

        let rawMinute = snappedMinute(atY: drag.location.y - drag.grabOffset)
        let duration = max(drag.task.durationMinutes, TimeGridLayout.minimumVisualMinutes)
        let latest = max(TimeGridLayout.minutesInDay - duration, 0) / snapMinutes * snapMinutes

        return DropTarget(
            dayIndex: min(max(day, 0), days.count - 1),
            minute: min(max(rawMinute, 0), latest),
            duration: drag.task.durationMinutes
        )
    }

    /// Минута шкалы с шагом привязки для точки в координатах видимой области.
    private func snappedMinute(atY y: CGFloat) -> Int {
        let contentY = y + viewport.offset - topPadding
        return Int((contentY / hourHeight * 60 / CGFloat(snapMinutes)).rounded()) * snapMinutes
    }

    /// Блок под пальцем с новым временем.
    @ViewBuilder
    private var dragPreview: some View {
        if let drag, drag.hasMoved, !isAboveGrid(drag), let target = dropTarget(for: drag) {
            let columnWidth = columnsWidth / CGFloat(days.count)
            let duration = max(target.duration, TimeGridLayout.minimumVisualMinutes)
            let height = CGFloat(min(duration, TimeGridLayout.minutesInDay - target.minute)) / 60 * hourHeight
            let startDate = calendar.date(
                byAdding: .minute,
                value: target.minute,
                to: calendar.startOfDay(for: days[target.dayIndex])
            ) ?? .now
            let endDate = startDate.addingTimeInterval(TimeInterval(target.duration * 60))

            VStack(alignment: .leading, spacing: 2) {
                Text(DateFormatting.time(for: startDate) + " – " + DateFormatting.time(for: endDate))
                    .font(.caption2.weight(.semibold))
                Text(drag.task.title)
                    .font(days.count == 7 ? .caption2 : .footnote)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, days.count == 7 ? 3 : 6)
            .padding(.vertical, 3)
            .frame(width: max(columnWidth - 2, 0), height: max(height - 2, 0), alignment: .topLeading)
            .background(AppColors.listColor(drag.task.list), in: .rect(cornerRadius: 6))
            .clipShape(.rect(cornerRadius: 6))
            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            .offset(
                x: CGFloat(target.dayIndex) * columnWidth + 1,
                y: CGFloat(target.minute) / 60 * hourHeight + 1
            )
            .allowsHitTesting(false)
            .sensoryFeedback(.selection, trigger: target)
        }
    }

    /// Пока палец у верхнего или нижнего края, двигаем шкалу, чтобы дотянуться до любого часа.
    private func autoScrollWhileDragging() async {
        let edge: CGFloat = 56
        let step: CGFloat = 3
        while drag != nil, !Task.isCancelled {
            // Удержание без движения не прокручивает, даже если блок лежит у края.
            if let drag, drag.hasMoved, !isAboveGrid(drag) {
                let y = drag.location.y
                var offset = viewport.offset
                if y < edge {
                    offset -= step
                } else if y > viewport.height - edge {
                    offset += step
                }
                offset = min(max(offset, 0), viewport.maxOffset)
                if offset != viewport.offset {
                    scrollPosition.scrollTo(y: offset)
                }
            }
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    private var nowIndicator: some View {
        TimelineView(.everyMinute) { context in
            let parts = calendar.dateComponents([.hour, .minute], from: context.date)
            let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            HStack(spacing: 0) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 7, height: 7)
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 1.5)
            }
            .offset(y: CGFloat(minutes) / 60 * hourHeight - 3.5)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func taskMenu(_ task: TaskItem) -> some View {
        Button {
            onToggle(task)
        } label: {
            Label(
                task.isCompleted ? "Снять отметку" : "Выполнено",
                systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark"
            )
        }
        Button(role: .destructive) {
            onDelete(task)
        } label: {
            Label("Удалить", systemImage: "trash")
        }
    }

    // MARK: - Данные

    private func blockFill(_ task: TaskItem) -> Color {
        AppColors.listColor(task.list).opacity(0.3)
    }

    private func timedTasks(on day: Date) -> [TaskItem] {
        tasks.filter { task in
            guard task.hasTime, let due = task.dueDate else { return false }
            return calendar.isDate(due, inSameDayAs: day)
        }
    }

    private func allDayTasks(on day: Date) -> [TaskItem] {
        tasks.filter { task in
            guard !task.hasTime, let due = task.dueDate else { return false }
            return calendar.isDate(due, inSameDayAs: day)
        }
    }

    private func create(on day: Date, atY y: CGFloat) {
        let minutes = Int(y / hourHeight * 60) / 30 * 30
        let start = calendar.date(byAdding: .minute, value: minutes, to: calendar.startOfDay(for: day))
        onCreate(start ?? day)
    }
}
