import Foundation
import Observation

/// Экран фокуса: кольцо, фаза, управление, пресеты и сводка за сегодня.
/// Состояние сессии живёт в `FocusEngine`, экран только показывает его и передаёт нажатия.
@MainActor
@Observable
final class FocusScreenViewModel {
    struct Dot: Identifiable, Equatable {
        let id: Int
        let isDone: Bool
        let isCurrent: Bool
    }

    struct PresetChip: Identifiable, Equatable {
        var id: Int { preset.rawValue }
        let preset: FocusPreset
        let title: String
        let isSelected: Bool
    }

    var isTaskPickerPresented = false
    var isSettingsPresented = false
    let stopFlow: FocusStopFlow
    let host: FocusEngine.ScreenHost

    @ObservationIgnored let focus: FocusEngine
    @ObservationIgnored private let entries: any TimeEntryRepository
    @ObservationIgnored private let tasks: any TaskRepository
    @ObservationIgnored private let format: DisplayFormatter
    @ObservationIgnored private let onOpenHistory: (() -> Void)?

    init(
        focus: FocusEngine,
        host: FocusEngine.ScreenHost,
        entries: any TimeEntryRepository,
        tasks: any TaskRepository,
        format: DisplayFormatter,
        stopFlow: FocusStopFlow,
        onOpenHistory: (() -> Void)? = nil
    ) {
        self.focus = focus
        self.host = host
        self.entries = entries
        self.tasks = tasks
        self.format = format
        self.stopFlow = stopFlow
        self.onOpenHistory = onOpenHistory
    }

    var run: FocusRun? { focus.run }
    private var now: Date { focus.now }
    private var settings: FocusSettings { focus.focusSettings }

    // MARK: - Шапка

    var title: String { run?.mode == .timer ? L10n.Focus.timeTracking : L10n.Focus.phaseFocus }
    var showsSettings: Bool { run?.mode != .timer }
    var task: TaskItem? { focus.task }
    var taskTitle: String { task?.title ?? L10n.Focus.noTaskLink }
    var taskColorHex: String? { task.map { $0.list?.colorHex ?? AppColors.fallbackList } }

    // MARK: - Кольцо

    var isBreak: Bool { run?.phase.isBreak == true }
    var isRunning: Bool { run?.isRunning == true }
    var timeText: String { run?.clockText(at: now) ?? "" }

    var phaseText: String {
        guard let run else { return "" }
        return run.isRunning || run.isReady ? FocusText.phase(run) : FocusText.phaseWithState(run)
    }

    var progress: Double { focus.progress }

    var subtitle: String {
        guard let run else { return "" }
        if run.mode == .timer {
            let tracked = DateFormatting.duration(minutes: Int((Double(task?.trackedMinutes ?? 0) * 60 + run.elapsed(at: now)) / 60))
            if let estimate = task?.effectiveEstimate {
                return L10n.Focus.timerOfEstimate(tracked, DateFormatting.duration(minutes: estimate))
            }
            return L10n.Focus.timerOnTask(tracked)
        }
        let minutes = Int((run.total ?? 0) / 60)
        return run.isReady && !run.isActive ? L10n.Focus.minuteSession(minutes) : L10n.Focus.ofMinutes(minutes)
    }

    // MARK: - Сессии цикла

    var showsDots: Bool { run?.mode == .focus }

    private var doneInCycle: Int {
        guard let run else { return 0 }
        let every = max(1, settings.longBreakEvery)
        return run.phase.isBreak && run.round % every == 0 ? every : run.round % every
    }

    var dots: [Dot] {
        let every = max(1, settings.longBreakEvery), done = doneInCycle
        return (0..<every).map { Dot(id: $0, isDone: $0 < done, isCurrent: $0 == done && !isBreak) }
    }

    var counterText: String {
        let every = max(1, settings.longBreakEvery)
        guard let run else { return "" }
        if run.phase == .longBreak { return L10n.Focus.longBreakCycle }
        if run.phase.isBreak { return L10n.Focus.sessionsDone(doneInCycle, every) }
        return L10n.Focus.sessionOf(doneInCycle + 1, every)
    }

    // MARK: - Кнопки

    var primaryTitle: String {
        guard let run else { return "" }
        if run.isRunning { return L10n.Focus.pause }
        if run.isReady { return run.phase.isBreak ? L10n.Focus.startBreak : L10n.Focus.start }
        return L10n.Focus.resume
    }

    var stopTitle: String {
        if run?.mode == .timer { return L10n.Focus.stopAndSave }
        return isBreak ? L10n.Focus.endCycle : L10n.Focus.stop
    }

    var canStop: Bool { run?.isActive == true }
    var showsSkip: Bool { isBreak }

    func togglePrimary() { focus.togglePause() }
    func stop() { stopFlow.stop() }
    func skipBreak() { focus.skipBreak() }
    func close() { focus.closeScreen() }

    // MARK: - Пресеты

    /// Пресеты видны, пока фокус ещё не начинали.
    var showsPresets: Bool { run?.mode == .focus && run?.isActive == false }

    var presets: [PresetChip] {
        FocusPreset.allCases.map { preset in
            let title = preset == .custom && settings.preset == .custom
                ? "\(settings.focusMinutes)/\(settings.shortBreakMinutes)"
                : FocusSettingsViewModel.title(of: preset)
            return PresetChip(preset: preset, title: title, isSelected: settings.preset == preset)
        }
    }

    /// Свой пресет открывает настройки, остальные применяются сразу.
    func selectPreset(_ preset: FocusPreset) {
        guard preset != .custom else {
            isSettingsPresented = true
            return
        }
        focus.updateSettings { $0.apply(preset) }
    }

    // MARK: - Задача

    var taskOptions: [TaskPickerOption] { TaskPickerOption.options(from: tasks.tasks, format: format) }

    func linkTask(_ id: UUID?) {
        focus.linkTask(id.flatMap { id in tasks.tasks.first { $0.id == id } })
        isTaskPickerPresented = false
    }

    // MARK: - Сегодня

    var todayText: String {
        let today = entries.entries(on: format.today, calendar: format.calendar)
        var minutes = today.filter(\.countsAsWork).reduce(0) { $0 + $1.durationMinutes }
        if let live = focus.liveInterval { minutes += Int(live.end.timeIntervalSince(live.start) / 60) }
        let sessions = today.filter { $0.kind == .focus && $0.status == .completed }.count
        return L10n.Focus.todaySummary(DateFormatting.duration(minutes: minutes), L10n.Focus.sessions(sessions))
    }

    /// Историю открывает только экран поверх приложения, а не поверх редактора задачи.
    var canOpenHistory: Bool { host == .root && onOpenHistory != nil }

    func openHistory() {
        focus.closeScreen()
        onOpenHistory?()
    }
}
