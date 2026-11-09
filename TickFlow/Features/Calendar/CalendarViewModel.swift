import CoreGraphics
import Foundation
import Observation

/// Календарь: четыре вида, полоса «весь день», перетаскивание с подсказкой, фильтр и поиск.
@MainActor
@Observable
final class CalendarViewModel {
    enum DragMode {
        case move, resizeTop, resizeBottom
        /// Полоса «весь день» целиком и её края.
        case shiftDays, extendStart, extendEnd
    }

    enum Dialog: Identifiable {
        case conflict(message: String)
        case recurring(message: String)

        var id: String {
            switch self {
            case .conflict: "conflict"
            case .recurring: "recurring"
            }
        }
    }

    struct MenuTask: Identifiable {
        let id: UUID
        let title: String
        let isCompleted: Bool
    }

    /// Положение задачи на календаре: дни и, для однодневной со временем, минуты.
    private struct Span: Equatable {
        var day: Date
        var lastDay: Date
        var start: Int
        var end: Int
        var isTimed: Bool
    }

    private struct DragState {
        let taskID: UUID
        let mode: DragMode
        let original: Span
        var preview: Span
        var hasMoved = false
    }

    private struct PendingChange {
        let taskID: UUID
        let draft: TaskDraft
        let message: String
    }

    // MARK: - Состояние

    var mode: CalendarMode {
        didSet {
            guard mode != oldValue else { return }
            settings.update { $0.lastCalendarMode = mode }
        }
    }
    private(set) var selectedDate: Date
    var editorRequest: TaskEditorRequest?
    var isSearchPresented = false
    var isFilterPresented = false
    var dialog: Dialog?
    var menuTask: MenuTask?
    /// Задача, только что созданная или перенесённая, — подсвечивается на секунду.
    private(set) var highlightedID: UUID?

    private var drag: DragState?
    @ObservationIgnored private var pending: PendingChange?
    @ObservationIgnored private var pendingScope: RecurringScope?

    @ObservationIgnored private let taskRepository: any TaskRepository
    @ObservationIgnored private let listRepository: any TaskListRepository
    @ObservationIgnored private let settings: any SettingsRepository
    @ObservationIgnored private let filter: TaskFilterStore
    @ObservationIgnored private let toasts: ToastCenter
    @ObservationIgnored private let actions: TaskActions
    @ObservationIgnored private let navigator: AppNavigator
    @ObservationIgnored private let loadSampleData: () -> Void
    @ObservationIgnored private let clock: any AppClock
    @ObservationIgnored private let timeEntries: (any TimeEntryRepository)?
    @ObservationIgnored let focus: FocusEngine?
    @ObservationIgnored private let makeSessionDetail: ((TimeEntry, @escaping (TaskItem) -> Void) -> SessionDetailViewModel)?
    /// Лист «Сессия» для нажатой полосы или строки.
    var sessionDetail: SessionDetailViewModel?
    /// Задача, открытая из листа сессии: редактор появится, когда лист закроется.
    @ObservationIgnored private var taskAfterSession: TaskItem?

    init(
        tasks: any TaskRepository,
        lists: any TaskListRepository,
        settings: any SettingsRepository,
        filter: TaskFilterStore,
        toasts: ToastCenter,
        navigator: AppNavigator,
        loadSampleData: @escaping () -> Void,
        timeEntries: (any TimeEntryRepository)? = nil,
        focus: FocusEngine? = nil,
        makeSessionDetail: ((TimeEntry, @escaping (TaskItem) -> Void) -> SessionDetailViewModel)? = nil,
        clock: any AppClock = SystemClock()
    ) {
        self.clock = clock
        self.timeEntries = timeEntries
        self.focus = focus
        self.makeSessionDetail = makeSessionDetail
        taskRepository = tasks
        listRepository = lists
        self.settings = settings
        self.filter = filter
        self.toasts = toasts
        self.navigator = navigator
        self.loadSampleData = loadSampleData
        actions = TaskActions(tasks: tasks, toasts: toasts)
        mode = settings.settings.lastCalendarMode ?? settings.settings.defaultCalendarMode
        selectedDate = DisplayFormatter(settings: settings.settings, clock: clock).today
    }

    private var format: DisplayFormatter { DisplayFormatter(settings: settings.settings, clock: clock) }
    private var calendar: Calendar { format.calendar }

    var geometry: TimelineGeometry { TimelineGeometry(mode: mode) }
    var isMonth: Bool { mode == .month }
    var isDay: Bool { mode == .day }

    // MARK: - Шапка

    var title: String {
        let days = visibleDays
        guard mode != .month, mode != .day, let first = days.first, let last = days.last,
              !calendar.isDate(first, equalTo: last, toGranularity: .month)
        else { return format.monthName(selectedDate) }
        return monthShort(first) + " – " + monthShort(last)
    }

    var year: String {
        let reference = mode == .month || mode == .day ? selectedDate : (visibleDays.last ?? selectedDate)
        return String(calendar.component(.year, from: reference))
    }

    var modeOptions: [(value: CalendarMode, title: String)] {
        [(.day, L10n.Calendar.day), (.threeDay, L10n.Calendar.threeDays), (.week, L10n.Calendar.week), (.month, L10n.Calendar.month)]
    }

    var isFilterActive: Bool { filter.isActive }

    func showPrevious() { shift(by: -1) }
    func showNext() { shift(by: 1) }

    func goToToday() {
        selectedDate = format.today
    }

    /// Свайп по шапке: влево — вперёд.
    /// Горизонтальный свайп листает период: месяц — на месяц, «День» — на неделю,
    /// остальные виды — на свою длину. Вертикальные жесты (прокрутка) игнорируются.
    func swipe(dx: CGFloat, dy: CGFloat = 0) {
        guard abs(dx) > 50, abs(dx) > abs(dy) * 1.5 else { return }
        let direction = dx < 0 ? 1 : -1
        if mode == .day {
            selectedDate = calendar.date(byAdding: .day, value: direction * 7, to: selectedDate) ?? selectedDate
        } else {
            shift(by: direction)
        }
    }

    func select(_ day: Date) {
        selectedDate = calendar.startOfDay(for: day)
    }

    /// Нажатие на заголовок колонки: открыть этот день в виде «День».
    func openDay(_ day: Date) {
        select(day)
        mode = .day
    }

    private func shift(by value: Int) {
        if mode == .month {
            guard let month = calendar.date(byAdding: .month, value: value, to: startOfMonth(selectedDate)) else { return }
            selectedDate = calendar.isDate(month, equalTo: format.now, toGranularity: .month) ? format.today : month
        } else {
            selectedDate = calendar.date(byAdding: .day, value: value * mode.dayCount, to: selectedDate) ?? selectedDate
        }
    }

    // MARK: - Дни

    var visibleDays: [Date] {
        switch mode {
        case .day, .month: return [selectedDate]
        case .threeDay: return (0..<3).compactMap { calendar.date(byAdding: .day, value: $0, to: selectedDate) }
        case .week: return week(of: selectedDate)
        }
    }

    /// Полоса дней недели в виде «День».
    var dayStrip: [CalendarItems.DayHeader] {
        let tasks = visibleTasks
        return week(of: selectedDate).map { day in
            header(for: day, symbol: format.veryShortWeekdays, hasTasks: tasks.contains { $0.occurs(on: day, calendar: calendar) })
        }
    }

    /// Заголовки колонок в видах «3 дня» и «Неделя».
    var columnHeaders: [CalendarItems.DayHeader] {
        visibleDays.map { header(for: $0, symbol: format.shortWeekdays, hasTasks: false) }
    }

    var dayLabel: String {
        format.fullDay(selectedDate) + (format.isToday(selectedDate) ? L10n.Common.todaySuffix : "")
    }

    func isToday(_ index: Int) -> Bool {
        visibleDays.indices.contains(index) && format.isToday(visibleDays[index])
    }

    // MARK: - Шкала

    func hourLabels(now: Date) -> [CalendarItems.HourLabel] {
        let nowMinute = nowLine(at: now) != nil ? format.minute(of: now) : nil
        return (0..<24).map { hour in
            let hidden = hour == 0 || nowMinute.map { abs(hour * 60 - $0) < 18 } ?? false
            return CalendarItems.HourLabel(hour: hour, text: hidden ? "" : format.hourLabel(hour))
        }
    }

    func nowLine(at now: Date) -> CalendarItems.NowLine? {
        guard let index = visibleDays.firstIndex(where: { calendar.isDate($0, inSameDayAs: now) }) else { return nil }
        let minute = format.minute(of: now)
        return CalendarItems.NowLine(dayIndex: index, minute: minute, label: format.shortTime(minute: minute))
    }

    /// Минута, к которой прокрутить шкалу при открытии: чуть выше текущего времени.
    var initialScrollMinute: Int {
        let showsToday = visibleDays.contains { format.isToday($0) }
        return showsToday
            ? max(0, format.minute(of: format.now) - 140)
            : max(0, settings.settings.workdayStartHour * 60 - 30)
    }

    var cards: [CalendarItems.Card] {
        let days = visibleDays
        let narrow = geometry.isNarrow
        var result: [CalendarItems.Card] = []

        for (index, day) in days.enumerated() {
            let items: [(TaskItem, Span)] = visibleTasks.compactMap { task in
                guard let span = span(of: task), span.isTimed, calendar.isDate(span.day, inSameDayAs: day) else { return nil }
                return (task, span)
            }
            let placements = TimeGridLayout.place(items.map { .init(id: $0.0.id, start: $0.1.start, end: $0.1.end) })
            for (task, span) in items {
                let placement = placements[task.id] ?? .init(lane: 0, laneCount: 1)
                let isDragging = drag?.taskID == task.id
                let startText = format.shortTime(minute: span.start)
                result.append(CalendarItems.Card(
                    id: task.id,
                    title: task.title,
                    time: narrow ? startText : startText + " – " + format.shortTime(minute: span.end),
                    dayIndex: index,
                    startMinute: span.start,
                    endMinute: span.end,
                    lane: placement.lane,
                    laneCount: placement.laneCount,
                    colorHex: task.list?.colorHex ?? AppColors.fallbackList,
                    isCompleted: task.isCompleted,
                    isDragging: isDragging,
                    isHighlighted: highlightedID == task.id,
                    hasConflict: placement.laneCount > 1 && !task.isCompleted && !isDragging
                ))
            }
        }
        return result
    }

    /// Пунктирный контур на старом месте, пока задачу тащат.
    var ghost: CalendarItems.Ghost? {
        guard let drag, drag.hasMoved, drag.original.isTimed,
              let index = visibleDays.firstIndex(where: { calendar.isDate($0, inSameDayAs: drag.original.day) }),
              let task = task(drag.taskID)
        else { return nil }
        return CalendarItems.Ghost(
            id: task.id, dayIndex: index, startMinute: drag.original.start, endMinute: drag.original.end,
            colorHex: task.list?.colorHex ?? AppColors.fallbackList
        )
    }

    var bars: [CalendarItems.Bar] {
        let days = visibleDays
        guard let first = days.first, let last = days.last else { return [] }
        let items: [(TaskItem, Span, Int, Int)] = visibleTasks.compactMap { task in
            guard let span = span(of: task), !span.isTimed, span.day <= last, span.lastDay >= first else { return nil }
            let start = days.firstIndex { calendar.isDate($0, inSameDayAs: max(span.day, first)) } ?? 0
            let end = days.firstIndex { calendar.isDate($0, inSameDayAs: min(span.lastDay, last)) } ?? days.count - 1
            return (task, span, start, end)
        }
        .sorted { ($0.1.day, -$0.1.lastDay.timeIntervalSince1970) < ($1.1.day, -$1.1.lastDay.timeIntervalSince1970) }

        let lanes = TimeGridLayout.lanes(for: items.map { .init(id: $0.0.id, first: $0.2, last: $0.3) })
        return items.map { task, span, start, end in
            CalendarItems.Bar(
                id: task.id,
                title: (span.day < first ? "‹ " : "") + task.title,
                first: start,
                last: end,
                lane: lanes.lanes[task.id] ?? 0,
                colorHex: task.list?.colorHex ?? AppColors.fallbackList,
                isCompleted: task.isCompleted,
                isMultiDay: !calendar.isDate(span.day, inSameDayAs: span.lastDay) && !task.isCompleted,
                isDragging: drag?.taskID == task.id
            )
        }
    }

    var allDayLaneCount: Int {
        (bars.map(\.lane).max() ?? -1) + 1
    }

    /// Чёрная плашка над шкалой во время перетаскивания.
    var hud: String? {
        guard let drag, drag.hasMoved else { return nil }
        let span = drag.preview
        if !span.isTimed {
            if calendar.isDate(span.day, inSameDayAs: span.lastDay) { return format.weekdayAndDay(span.day) }
            let days = (calendar.dateComponents([.day], from: span.day, to: span.lastDay).day ?? 0) + 1
            return format.shortRange(span.day, span.lastDay) + " · " + L10n.Format.daysShort(days)
        }
        let weekday = mode == .day ? "" : format.shortWeekdays[weekdayIndex(of: span.day)] + "  "
        var text = weekday + format.time(minute: span.start) + " – " + format.time(minute: span.end)
            + " · " + format.duration(minutes: span.end - span.start)
        if conflict(for: drag.taskID, span: span) != nil { text += L10n.Common.overlapsShort }
        return text
    }

    /// Меняется при каждом шаге перетаскивания — для тактильного отклика.
    var dragStepKey: String {
        guard let drag else { return "" }
        let p = drag.preview
        return "\(p.day.timeIntervalSince1970)-\(p.lastDay.timeIntervalSince1970)-\(p.start)-\(p.end)"
    }

    var isDragging: Bool { drag != nil }

    // MARK: - Пустые состояния

    var isFirstRun: Bool { taskRepository.tasks.isEmpty && mode != .month }

    var isDayEmpty: Bool {
        !isFirstRun && mode == .day && !visibleTasks.contains { $0.occurs(on: selectedDate, calendar: calendar) }
    }

    func addFirstHabit() { navigator.openNewHabit() }

    /// Запрос «Создать первую задачу» из онбординга.
    var wantsNewTask: Bool { navigator.wantsNewTask }

    func handleNewTaskRequest() {
        guard navigator.wantsNewTask else { return }
        navigator.wantsNewTask = false
        beginCreatingTask()
    }

    /// Вид по умолчанию из настроек: при его смене календарь переключается.
    var preferredMode: CalendarMode { settings.settings.defaultCalendarMode }

    func applyPreferredMode() {
        mode = preferredMode
    }
    func loadSample() { loadSampleData() }

    // MARK: - Месяц

    var weekdaySymbols: [String] { format.shortWeekdays }

    var monthCells: [CalendarItems.MonthCell] {
        guard let interval = calendar.dateInterval(of: .month, for: selectedDate) else { return [] }
        let first = interval.start
        let lead = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let dayCount = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let rows = Int((Double(lead + dayCount) / 7).rounded(.up))
        guard let start = calendar.date(byAdding: .day, value: -lead, to: first) else { return [] }
        let tasks = visibleTasks
        let today = format.today

        return (0..<(rows * 7)).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let onDay = tasks.filter { $0.occurs(on: day, calendar: calendar) }
            return CalendarItems.MonthCell(
                id: day,
                number: String(calendar.component(.day, from: day)),
                isInMonth: calendar.isDate(day, equalTo: first, toGranularity: .month),
                isToday: calendar.isDate(day, inSameDayAs: today),
                isSelected: calendar.isDate(day, inSameDayAs: selectedDate),
                dotHexes: onDay.prefix(3).map { task in
                    task.isCompleted ? "#D1D1D6" : day < today ? "#E5484D" : (task.list?.colorHex ?? AppColors.fallbackList)
                },
                more: onDay.count > 3 ? "+\(onDay.count - 3)" : "",
                tracked: trackedLabel(on: day)
            )
        }
    }

    // MARK: - Учтённое время

    /// Записи работы за день: без перерывов и отброшенных.
    func workEntries(on day: Date) -> [TimeEntry] {
        guard let timeEntries else { return [] }
        return timeEntries.entries(on: day, calendar: calendar)
            .filter { $0.countsAsWork }
            .sorted { $0.start < $1.start }
    }

    private func trackedLabel(on day: Date) -> String {
        let minutes = workEntries(on: day).reduce(0) { $0 + $1.durationMinutes }
        return minutes > 0 ? DateFormatting.duration(minutes: minutes).replacingOccurrences(of: " ", with: "") : ""
    }

    /// Полосы записей в колонках «Дня», «3 дней» и «Недели».
    var sessions: [CalendarItems.Session] {
        guard !isMonth else { return [] }
        return visibleDays.enumerated().flatMap { index, day in
            workEntries(on: day).map { entry in
                let start = format.minute(of: entry.start)
                let end = calendar.isDate(entry.end, inSameDayAs: entry.start) ? format.minute(of: entry.end) : 1440
                var detail = FocusText.kind(entry.kind) + " · " + DateFormatting.duration(minutes: entry.durationMinutes)
                if entry.status == .interrupted { detail += " · " + L10n.Calendar.sessionStopped }
                return CalendarItems.Session(
                    id: entry.id, dayIndex: index, startMinute: start, endMinute: max(end, start + 1),
                    title: SessionDetailViewModel.title(for: entry), detail: detail,
                    colorHex: entry.task?.list?.colorHex ?? AppColors.fallbackList,
                    isInterrupted: entry.status == .interrupted
                )
            }
        }
    }

    /// Идёт учёт: сессия фокуса или таймер, не перерыв.
    private var isTrackingLive: Bool {
        guard let run = focus?.run else { return false }
        return run.isActive && !run.phase.isBreak && !run.isReady
    }

    /// Колонка сегодняшнего дня, если сейчас идёт учёт.
    var liveDayIndex: Int? {
        guard isTrackingLive, !isMonth else { return nil }
        return visibleDays.firstIndex { format.isToday($0) }
    }

    /// Колонки с полосой учтённого времени: задачи в них уже.
    var sessionDayIndexes: Set<Int> {
        var indexes = Set(sessions.map(\.dayIndex))
        if let live = liveDayIndex { indexes.insert(live) }
        return indexes
    }

    var trackedRows: [CalendarItems.TrackedRow] {
        workEntries(on: selectedDate).map { entry in
            CalendarItems.TrackedRow(
                id: entry.id,
                title: SessionDetailViewModel.title(for: entry),
                time: format.time(entry.start) + " – " + format.time(entry.end) + " · " + FocusText.kind(entry.kind),
                duration: DateFormatting.duration(minutes: entry.durationMinutes),
                kind: entry.kind,
                colorHex: entry.task?.list?.colorHex,
                hasTask: entry.task != nil,
                isInterrupted: entry.status == .interrupted
            )
        }
    }

    var trackedMinutes: Int { workEntries(on: selectedDate).reduce(0) { $0 + $1.durationMinutes } }

    /// Сессия идёт в выбранный день — строка «Идёт» в списке.
    var showsLiveTracked: Bool { isTrackingLive && format.isToday(selectedDate) }

    func openSession(_ id: UUID) {
        guard let makeSessionDetail, let entry = timeEntries?.entries.first(where: { $0.id == id }) else { return }
        sessionDetail = makeSessionDetail(entry) { [weak self] in self?.openTaskFromSession($0) }
    }

    func timeText(_ date: Date) -> String { format.time(date) }
    func minute(of date: Date) -> Int { format.minute(of: date) }

    func openLiveSession() {
        focus?.present()
    }

    /// «Открыть задачу» из листа сессии.
    func openTaskFromSession(_ task: TaskItem) {
        taskAfterSession = task
    }

    func sessionClosed() {
        sessionDetail = nil
        if let task = taskAfterSession {
            taskAfterSession = nil
            editorRequest = .edit(task)
        }
    }

    var agendaTitle: String {
        format.isToday(selectedDate) ? L10n.Common.today : format.fullDay(selectedDate)
    }

    var agenda: [CalendarItems.AgendaRow] {
        let day = selectedDate
        return visibleTasks
            .filter { $0.occurs(on: day, calendar: calendar) }
            .sorted { agendaKey($0) < agendaKey($1) }
            .map { task in
                CalendarItems.AgendaRow(
                    id: task.id,
                    title: task.title,
                    time: agendaTime(task, on: day),
                    colorHex: task.list?.colorHex ?? AppColors.fallbackList,
                    isCompleted: task.isCompleted,
                    isUrgent: task.priority == .high
                )
            }
    }

    var agendaCount: String {
        let rows = agenda
        return rows.isEmpty ? "" : L10n.Common.doneOfTotal(rows.filter(\.isCompleted).count, rows.count)
    }

    // MARK: - Создание и действия

    /// Кнопка «+»: на сегодня — ближайший час, на другой день — 9:00.
    func beginCreatingTask() {
        let isToday = format.isToday(selectedDate)
        let nextHour = min(23, calendar.component(.hour, from: format.now) + 1)
        editorRequest = .new(day: selectedDate, startMinute: isToday ? nextHour * 60 : 540, list: listRepository.lists.first)
    }

    /// Нажатие на свободное место шкалы.
    func beginCreatingTask(dayIndex: Int, y: CGFloat) {
        guard visibleDays.indices.contains(dayIndex) else { return }
        editorRequest = .new(day: visibleDays[dayIndex], startMinute: geometry.slotMinute(atY: y), list: listRepository.lists.first)
    }

    func open(_ id: UUID) {
        guard let task = task(id) else { return }
        editorRequest = .edit(task)
    }

    func toggle(_ id: UUID) {
        guard let task = task(id) else { return }
        actions.toggleCompleted(task)
    }

    func showMenu(_ id: UUID) {
        guard let task = task(id) else { return }
        menuTask = MenuTask(id: id, title: task.title, isCompleted: task.isCompleted)
    }

    func deleteFromMenu() {
        guard let id = menuTask?.id, let task = task(id) else { return }
        menuTask = nil
        actions.delete(task)
    }

    func toggleFromMenu() {
        guard let id = menuTask?.id else { return }
        menuTask = nil
        toggle(id)
    }

    // MARK: - Перетаскивание

    func beginDrag(_ id: UUID, mode dragMode: DragMode) {
        guard let task = task(id), !task.isCompleted, let span = span(of: task) else { return }
        drag = DragState(taskID: id, mode: dragMode, original: span, preview: span)
    }

    /// Смещение пальца от начала жеста в точках.
    func updateDrag(dx: CGFloat, dy: CGFloat, columnWidth: CGFloat) {
        guard var state = drag else { return }
        if !state.hasMoved, hypot(dx, dy) < 6 { return }
        state.hasMoved = true

        let o = state.original
        let minutes = geometry.snappedMinutes(forDelta: dy)
        let dayDelta = columnWidth > 0 ? Int((dx / columnWidth).rounded()) : 0
        var p = o

        switch state.mode {
        case .move:
            let duration = o.end - o.start
            p.start = min(max(0, o.start + minutes), 1440 - duration)
            p.end = p.start + duration
            if mode != .day, let index = visibleDays.firstIndex(where: { calendar.isDate($0, inSameDayAs: o.day) }) {
                let target = min(max(0, index + dayDelta), visibleDays.count - 1)
                p.day = visibleDays[target]
                p.lastDay = p.day
            }
        case .resizeBottom:
            p.end = min(max(o.start + 15, o.end + minutes), 1440)
        case .resizeTop:
            p.start = max(0, min(o.end - 15, o.start + minutes))
        case .shiftDays:
            p.day = adding(dayDelta, to: o.day)
            p.lastDay = adding(dayDelta, to: o.lastDay)
        case .extendStart:
            p.day = min(o.lastDay, adding(dayDelta, to: o.day))
        case .extendEnd:
            p.lastDay = max(o.day, adding(dayDelta, to: o.lastDay))
        }
        state.preview = p
        drag = state
    }

    /// Палец отпущен. Удержание без движения открывает меню задачи.
    func endDrag() {
        guard let state = drag else { return }
        drag = nil
        guard state.hasMoved else {
            showMenu(state.taskID)
            return
        }
        guard state.preview != state.original, let task = task(state.taskID) else { return }
        propose(task: task, mode: state.mode, span: state.preview, original: state.original)
    }

    func cancelDrag() {
        drag = nil
    }

    // MARK: - Диалоги

    func resolveRecurring(_ scope: RecurringScope) {
        dialog = nil
        guard let pending, let task = task(pending.taskID) else { return }
        if let message = conflictMessage(for: pending.draft, excluding: task.id) {
            pendingScope = scope
            dialog = .conflict(message: message)
            return
        }
        commit(pending, scope: scope)
    }

    func confirmConflict() {
        dialog = nil
        guard let pending else { return }
        commit(pending, scope: pendingScope)
    }

    func cancelDialog() {
        dialog = nil
        pending = nil
        pendingScope = nil
    }

    // MARK: - Внутреннее

    private var visibleTasks: [TaskItem] {
        taskRepository.tasks.filter { filter.matches($0) }
    }

    private func task(_ id: UUID) -> TaskItem? {
        taskRepository.tasks.first { $0.id == id }
    }

    /// Положение задачи с учётом текущего перетаскивания.
    private func span(of task: TaskItem) -> Span? {
        if let drag, drag.taskID == task.id { return drag.preview }
        guard let due = task.dueDate, let last = task.lastDay else { return nil }
        let day = calendar.startOfDay(for: due)
        guard task.hasTime, !task.isMultiDay else {
            return Span(day: day, lastDay: last, start: 0, end: 0, isTimed: false)
        }
        let start = format.minute(of: due)
        return Span(day: day, lastDay: day, start: start, end: min(1440, start + task.durationMinutes), isTimed: true)
    }

    private func propose(task: TaskItem, mode dragMode: DragMode, span: Span, original: Span) {
        var draft = TaskSnapshot(task).draft
        let message: String

        if span.isTimed {
            draft.dueDate = calendar.date(byAdding: .minute, value: span.start, to: span.day)
            draft.durationMinutes = span.end - span.start
            draft.endDay = nil
            switch dragMode {
            case .resizeTop, .resizeBottom:
                message = format.time(minute: span.start) + " – " + format.time(minute: span.end)
                    + " · " + format.duration(minutes: span.end - span.start)
            default:
                let dayPart = calendar.isDate(span.day, inSameDayAs: original.day) ? "" : format.relativeDay(span.day) + ", "
                message = L10n.Calendar.movedTo(dayPart + format.time(minute: span.start))
            }
        } else {
            let startShift = calendar.dateComponents([.day], from: original.day, to: span.day).day ?? 0
            let endShift = calendar.dateComponents([.day], from: original.lastDay, to: span.lastDay).day ?? 0
            if let due = task.dueDate {
                draft.dueDate = calendar.date(byAdding: .day, value: startShift, to: due)
            }
            draft.endDay = calendar.isDate(span.day, inSameDayAs: span.lastDay) ? nil : span.lastDay
            if task.hasTime, let end = task.endDate, let newStart = draft.dueDate,
               let newEnd = calendar.date(byAdding: .day, value: endShift, to: end) {
                draft.durationMinutes = max(15, Int(newEnd.timeIntervalSince(newStart) / 60))
            }
            message = calendar.isDate(span.day, inSameDayAs: span.lastDay)
                ? L10n.Calendar.movedTo(format.weekdayAndDay(span.day))
                : L10n.Calendar.nowRange(format.shortRange(span.day, span.lastDay))
        }

        let change = PendingChange(taskID: task.id, draft: draft, message: message)
        pending = change
        if task.repeatRule != .never {
            dialog = .recurring(message: ScheduleCommit.recurringMessage(title: task.title, rule: task.repeatRule))
        } else if let conflict = conflictMessage(for: draft, excluding: task.id) {
            dialog = .conflict(message: conflict)
        } else {
            commit(change, scope: nil)
        }
    }

    private func commit(_ change: PendingChange, scope: RecurringScope?) {
        pending = nil
        pendingScope = nil
        guard let task = task(change.taskID) else { return }
        let undo = ScheduleCommit.commit(change.draft, to: task, scope: scope, repository: taskRepository)

        var message = change.message
        if change.draft.hasTime, change.draft.endDay == nil, let start = change.draft.dueDate {
            let end = start.addingTimeInterval(TimeInterval(change.draft.durationMinutes * 60))
            message += ScheduleCommit.gapNote(start: start, end: end, excluding: task.id, in: taskRepository.tasks, calendar: calendar)
        }
        if scope == .thisOccurrence { message += L10n.Common.thisOccurrenceSuffix }
        toasts.show(message, undo: undo)
        flash(task.id)
    }

    private func conflictMessage(for draft: TaskDraft, excluding id: UUID) -> String? {
        guard draft.hasTime, draft.endDay == nil, let start = draft.dueDate else { return nil }
        let end = start.addingTimeInterval(TimeInterval(draft.durationMinutes * 60))
        guard let other = ConflictDetector.conflict(start: start, end: end, excluding: id, in: taskRepository.tasks),
              let otherStart = other.dueDate, let otherEnd = other.endDate
        else { return nil }
        return L10n.Common.overlapMessage(draft.title, other.title, format.time(otherStart), format.time(otherEnd))
    }

    private func conflict(for id: UUID, span: Span) -> TaskItem? {
        guard let start = calendar.date(byAdding: .minute, value: span.start, to: span.day),
              let end = calendar.date(byAdding: .minute, value: span.end, to: span.day) else { return nil }
        return ConflictDetector.conflict(start: start, end: end, excluding: id, in: taskRepository.tasks, calendar: calendar)
    }

    private func flash(_ id: UUID) {
        highlightedID = id
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            if self?.highlightedID == id { self?.highlightedID = nil }
        }
    }

    private func header(for day: Date, symbol: [String], hasTasks: Bool) -> CalendarItems.DayHeader {
        CalendarItems.DayHeader(
            id: day,
            weekday: symbol[weekdayIndex(of: day)],
            number: String(calendar.component(.day, from: day)),
            isToday: format.isToday(day),
            isSelected: calendar.isDate(day, inSameDayAs: selectedDate),
            hasTasks: hasTasks
        )
    }

    /// Позиция дня в неделе с учётом первого дня недели из настроек.
    private func weekdayIndex(of day: Date) -> Int {
        (calendar.component(.weekday, from: day) - calendar.firstWeekday + 7) % 7
    }

    private func week(of day: Date) -> [Date] {
        guard let start = calendar.date(byAdding: .day, value: -weekdayIndex(of: day), to: day) else { return [day] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func startOfMonth(_ date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? date
    }

    private func adding(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    private func monthShort(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).locale(format.locale)).capitalizedFirst
    }

    private func agendaKey(_ task: TaskItem) -> (Int, Date) {
        let allDay = !task.hasTime || task.isMultiDay
        return (allDay ? 0 : 1, task.dueDate ?? .distantFuture)
    }

    private func agendaTime(_ task: TaskItem, on day: Date) -> String {
        if task.isMultiDay, let due = task.dueDate, let last = task.lastDay {
            let index = (calendar.dateComponents([.day], from: calendar.startOfDay(for: due), to: day).day ?? 0) + 1
            let total = (calendar.dateComponents([.day], from: calendar.startOfDay(for: due), to: last).day ?? 0) + 1
            return L10n.Calendar.dayOfTotal(index, total)
        }
        guard task.hasTime, let due = task.dueDate, let end = task.endDate else { return L10n.Common.allDay }
        return format.time(due) + " – " + format.time(end)
    }
}
