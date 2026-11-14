import Foundation
import Observation

/// Сессии фокуса и таймер задач. Один экземпляр на приложение: мини-плеер, экран фокуса,
/// строки задач и календарь читают одно состояние.
///
/// Правила (как в макете):
/// - фокус → короткий перерыв → … → после N сессий длинный перерыв, затем цикл сначала;
/// - фаза короче 30 секунд не сохраняется;
/// - запуск новой сессии сохраняет текущую: таймер — как завершённый, фокус — как прерванный;
/// - запись времени заканчивается в момент остановки, а начинается на прошедшее время раньше,
///   поэтому паузы не попадают в длительность.
@MainActor
@Observable
final class FocusEngine {
    struct Banner: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let body: String
    }

    /// Откуда открыт экран фокуса. Редактор задачи — полноэкранный, поэтому поверх него
    /// экран показывает сам редактор, а не корень приложения.
    enum ScreenHost: Equatable {
        case root
        case editor
    }

    /// Что показать после нажатия «Стоп».
    enum StopResult: Equatable {
        /// Сохранять нечего — сессия закрыта.
        case ended
        /// Фокус остановлен на середине: спросить, сохранить ли как прерванный. Сессия продолжает идти.
        case confirm(minutes: Int, of: Int)
        /// Таймер на паузе: показать лист сохранения с этими временами.
        case saveTimer(start: Date, end: Date)
        /// Остановлен перерыв: цикл закончен, перерыв сохранён.
        case cycleEnded
    }

    /// Короче — не сохраняется.
    static let minimumRecorded: TimeInterval = 30
    static let tickInterval: Duration = .milliseconds(500)
    private static let storageKey = "focus.run"

    private(set) var run: FocusRun?
    private(set) var screenHost: ScreenHost?
    var isScreenPresented: Bool { screenHost != nil }
    private(set) var banner: Banner?
    /// Время последнего тика. Экраны, которые его читают, обновляются, пока сессия идёт.
    private(set) var now: Date

    @ObservationIgnored private let entries: any TimeEntryRepository
    @ObservationIgnored private let tasks: any TaskRepository
    @ObservationIgnored private let settings: any SettingsRepository
    @ObservationIgnored private let clock: any AppClock
    @ObservationIgnored private let alerts: any FocusAlertScheduling
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let autoTick: Bool
    @ObservationIgnored private var tickTask: Task<Void, Never>?

    init(
        entries: any TimeEntryRepository,
        tasks: any TaskRepository,
        settings: any SettingsRepository,
        clock: any AppClock = SystemClock(),
        alerts: any FocusAlertScheduling = SystemFocusAlertScheduler(),
        defaults: UserDefaults = .standard,
        autoTick: Bool = true
    ) {
        self.entries = entries
        self.tasks = tasks
        self.settings = settings
        self.clock = clock
        self.alerts = alerts
        self.defaults = defaults
        self.autoTick = autoTick
        now = clock.now
        restore()
    }

    // MARK: - Чтение

    var focusSettings: FocusSettings { settings.settings.focus }

    /// Задача текущей сессии. `nil` — без задачи или задача удалена.
    var task: TaskItem? { run?.taskID.flatMap(task(for:)) }

    /// Сессия начата: мини-плеер и живые отметки видны.
    var isActive: Bool { run?.isActive == true }

    /// Доля кольца: фаза фокуса или потраченное на задачу от оценки для таймера.
    var progress: Double {
        guard let run else { return 0 }
        guard run.mode == .timer else { return run.progress(at: now) }
        let estimate = task?.effectiveEstimate.map { TimeInterval($0 * 60) }
        let tracked = TimeInterval((task?.trackedMinutes ?? 0) * 60)
        return run.progress(at: now, estimateSeconds: estimate, alreadyTracked: tracked)
    }

    func isLive(_ task: TaskItem) -> Bool { isLive(taskID: task.id) }

    func isLive(taskID: UUID) -> Bool {
        guard let run, run.isActive else { return false }
        return run.taskID == taskID
    }

    /// Набрано в текущей фазе работы над задачей, секунды. Перерывы не считаются.
    func liveSeconds(for task: TaskItem) -> TimeInterval { liveSeconds(taskID: task.id) }

    func liveSeconds(taskID: UUID) -> TimeInterval {
        guard let run, run.taskID == taskID, run.isTrackingWork(at: now) else { return 0 }
        return run.elapsed(at: now)
    }

    /// Потрачено на задачу с учётом идущей сессии, минуты.
    func trackedMinutes(for task: TaskItem) -> Int {
        task.trackedMinutes + Int((liveSeconds(for: task) / 60).rounded())
    }

    /// Идущая работа как отрезок: для календаря и истории.
    var liveInterval: (start: Date, end: Date, taskID: UUID?, kind: TimeEntryKind)? {
        guard let run, run.isTrackingWork(at: now) else { return nil }
        let elapsed = run.elapsed(at: now)
        return (now.addingTimeInterval(-elapsed), now, run.taskID, run.entryKind)
    }

    // MARK: - Запуск

    /// Фокус на задаче (или без неё). Тот же фокус уже идёт — только открывает экран.
    func startFocus(task: TaskItem?, present: Bool = true, on host: ScreenHost = .root) {
        refresh()
        if let run, run.isActive {
            if run.mode == .focus, run.taskID == task?.id {
                screenHost = host
                return
            }
            record(run.mode == .timer ? .completed : .interrupted, run, end: now)
        }
        var next = FocusRun(mode: .focus, taskID: task?.id, total: length(of: .focus), isActive: true)
        next.resume(at: now)
        set(next)
        if present { screenHost = host }
    }

    /// Секундомер на задаче. Экран не открывается — время видно в строке и мини-плеере.
    func startTimer(task: TaskItem) {
        refresh()
        if let run, run.isActive {
            if run.mode == .timer, run.taskID == task.id { return }
            record(run.mode == .timer ? .completed : .interrupted, run, end: now)
        }
        var next = FocusRun(mode: .timer, taskID: task.id, total: nil, isActive: true)
        next.resume(at: now)
        set(next)
    }

    /// «Фокус» без задачи: открывает текущую сессию или готовит новую, не запуская её.
    func openFocus(on host: ScreenHost = .root) {
        refresh()
        if run == nil {
            set(FocusRun(mode: .focus, taskID: nil, total: length(of: .focus), isActive: false))
        }
        screenHost = host
    }

    func present(on host: ScreenHost = .root) {
        guard run != nil else { return }
        screenHost = host
    }

    /// Закрывает экран. Не начатая сессия при этом исчезает, идущая продолжается в мини-плеере.
    func closeScreen() {
        screenHost = nil
        if run?.isActive == false { set(nil) }
    }

    // MARK: - Управление

    func pause() {
        refresh()
        guard var run, run.isRunning else { return }
        run.pause(at: now)
        set(run)
    }

    func resume() {
        refresh()
        guard var run, !run.isRunning else { return }
        run.resume(at: now)
        set(run)
    }

    func togglePause() {
        if run?.isRunning == true { pause() } else { resume() }
    }

    /// Привязывает сессию к задаче. Уже набранное время фазы уйдёт в эту задачу.
    func linkTask(_ task: TaskItem?) {
        guard var run else { return }
        run.taskID = task?.id
        set(run)
    }

    /// Пропуск перерыва: перерыв сохраняется, сразу начинается фокус.
    func skipBreak() {
        refresh()
        guard let run, run.phase.isBreak else { return }
        record(.completed, run, end: now)
        var next = FocusRun(
            mode: .focus, taskID: run.taskID, total: length(of: .focus),
            round: run.phase == .longBreak ? 0 : run.round, isActive: true
        )
        next.resume(at: now)
        set(next)
    }

    func stop() -> StopResult {
        refresh()
        guard var run else { return .ended }
        guard run.isActive else {
            clear()
            return .ended
        }
        if run.mode == .timer {
            run.pause(at: now)
            set(run)
            let elapsed = run.elapsed(at: now)
            return .saveTimer(start: now.addingTimeInterval(-elapsed), end: now)
        }
        if run.phase.isBreak {
            record(.completed, run, end: now)
            clear()
            return .cycleEnded
        }
        if run.isReady {
            clear()
            return .ended
        }
        let minutes = max(1, Int((run.elapsed(at: now) / 60).rounded()))
        return .confirm(minutes: minutes, of: Int((run.total ?? 0) / 60))
    }

    /// Ответ на `.confirm`: сохранить как прерванную.
    @discardableResult
    func saveInterrupted() -> TimeEntry? {
        refresh()
        guard let run else { return nil }
        let entry = record(.interrupted, run, end: now)
        clear()
        return entry
    }

    /// Ответ на `.confirm`: сессия остаётся в истории отброшенной и не входит в итоги.
    func discardSession() {
        refresh()
        guard let run else { return }
        record(.cancelled, run, end: now)
        clear()
    }

    /// Ответ на `.saveTimer`: сохранить запись с исправленными временами.
    @discardableResult
    func finishTimer(_ draft: TimeEntryDraft) -> TimeEntry? {
        guard draft.isValid else { return nil }
        var draft = draft
        draft.kind = .timer
        let entry = entries.add(draft)
        clear()
        return entry
    }

    /// Ответ на `.saveTimer`: отбросить. Запись остаётся отброшенной.
    func discardTimer(start: Date, end: Date) {
        guard let run else { return }
        entries.add(TimeEntryDraft(task: run.taskID.flatMap(task(for:)), start: start, end: end, kind: .timer, status: .cancelled))
        clear()
    }

    /// Лист сохранения таймера закрыт без решения — таймер идёт дальше.
    func continueTimer() {
        resume()
    }

    // MARK: - Настройки

    /// Меняет настройки фокуса и применяет их к ещё не начатой фазе.
    func updateSettings(_ change: (inout FocusSettings) -> Void) {
        settings.update { change(&$0.focus) }
        settingsChanged()
    }

    /// После смены длительностей: фаза, которая ещё не начиналась, берёт новую длину.
    func settingsChanged() {
        guard var run, run.mode == .focus, run.isReady else {
            scheduleAlert()
            return
        }
        run.total = length(of: run.phase)
        set(run)
    }

    func dismissBanner() {
        banner = nil
    }

    // MARK: - Время

    /// Проверяет, не закончилась ли фаза. Пропущенные в фоне фазы закрываются задним числом —
    /// в те моменты, когда они на самом деле закончились.
    func refresh() {
        now = clock.now
        while let run, let endsAt = run.endsAt, endsAt <= now {
            completePhase(at: endsAt)
        }
    }

    private func completePhase(at moment: Date) {
        guard let run, let total = run.total else { return }
        var finished = run
        finished.accumulated = total
        finished.resumedAt = nil
        record(.completed, finished, end: moment)

        let settings = focusSettings
        // Баннер — только если фаза закончилась только что, а не пока приложение было закрыто.
        let isFresh = now.timeIntervalSince(moment) < 5
        var next: FocusRun
        if run.phase == .focus {
            let round = run.round + 1
            let phase: FocusRun.Phase = round % max(1, settings.longBreakEvery) == 0 ? .longBreak : .shortBreak
            next = FocusRun(mode: .focus, taskID: run.taskID, phase: phase, total: length(of: phase), round: round, isActive: true)
            if settings.autoStartBreaks { next.resumedAt = moment }
            if isFresh { show(focusCompletedText(run, next: next)) }
        } else {
            let round = run.phase == .longBreak ? 0 : run.round
            next = FocusRun(mode: .focus, taskID: run.taskID, total: length(of: .focus), round: round, isActive: true)
            if settings.autoStartFocus { next.resumedAt = moment }
            if isFresh { show(breakOverText(round: round)) }
        }
        set(next)
    }

    // MARK: - Внутреннее

    private func task(for id: UUID) -> TaskItem? {
        tasks.tasks.first { $0.id == id }
    }

    private func length(of phase: FocusRun.Phase) -> TimeInterval {
        let settings = focusSettings
        let minutes = switch phase {
        case .focus: settings.focusMinutes
        case .shortBreak: settings.shortBreakMinutes
        case .longBreak: settings.longBreakMinutes
        }
        return TimeInterval(minutes * 60)
    }

    /// Сохраняет фазу как запись. Не начатая, слишком короткая или пустая не сохраняется.
    @discardableResult
    private func record(_ status: TimeEntryStatus, _ run: FocusRun, end: Date) -> TimeEntry? {
        guard run.isActive else { return nil }
        let elapsed = run.elapsed(at: end)
        guard elapsed > 0, elapsed >= Self.minimumRecorded || status == .cancelled else { return nil }
        let task = run.phase.isBreak ? nil : run.taskID.flatMap(task(for:))
        return entries.add(TimeEntryDraft(
            task: task, start: end.addingTimeInterval(-elapsed), end: end, kind: run.entryKind, status: status
        ))
    }

    private func clear() {
        set(nil)
        screenHost = nil
    }

    private func set(_ run: FocusRun?) {
        self.run = run
        persist()
        scheduleAlert()
        updateTicking()
    }

    private func show(_ text: (title: String, body: String)) {
        guard focusSettings.sessionNotifications else { return }
        banner = Banner(title: text.title, body: text.body)
    }

    private func focusCompletedText(_ run: FocusRun, next: FocusRun) -> (title: String, body: String) {
        let minutes = Int((run.total ?? 0) / 60)
        let breakMinutes = Int((next.total ?? 0) / 60)
        let body = run.taskID.flatMap(task(for:)).map { L10n.Focus.completedBodyTask(minutes, $0.title, breakMinutes) }
            ?? L10n.Focus.completedBody(minutes, breakMinutes)
        return (L10n.Focus.completedTitle, body)
    }

    private func breakOverText(round: Int) -> (title: String, body: String) {
        let every = max(1, focusSettings.longBreakEvery)
        return (L10n.Focus.breakOverTitle, L10n.Focus.breakOverBody(round % every + 1, every))
    }

    /// Уведомление на конец идущей фазы: экран может быть закрыт или телефон заблокирован.
    private func scheduleAlert() {
        guard focusSettings.sessionNotifications, let run, let endsAt = run.endsAt else {
            alerts.cancel()
            return
        }
        let text: (title: String, body: String)
        if run.phase == .focus {
            let round = run.round + 1
            let phase: FocusRun.Phase = round % max(1, focusSettings.longBreakEvery) == 0 ? .longBreak : .shortBreak
            var next = run
            next.total = length(of: phase)
            text = focusCompletedText(run, next: next)
        } else {
            text = breakOverText(round: run.phase == .longBreak ? 0 : run.round)
        }
        alerts.schedule(title: text.title, body: text.body, at: endsAt)
    }

    private func updateTicking() {
        guard autoTick else { return }
        guard run?.isRunning == true else {
            tickTask?.cancel()
            tickTask = nil
            return
        }
        guard tickTask == nil else { return }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.tickInterval)
                guard let self, !Task.isCancelled else { return }
                self.refresh()
                if self.run?.isRunning != true {
                    self.tickTask = nil
                    return
                }
            }
        }
    }

    private func persist() {
        if let run, let data = try? JSONEncoder().encode(run) {
            defaults.set(data, forKey: Self.storageKey)
        } else {
            defaults.removeObject(forKey: Self.storageKey)
        }
    }

    private func restore() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let stored = try? JSONDecoder().decode(FocusRun.self, from: data)
        else { return }
        // Не начатая сессия после перезапуска не нужна.
        guard stored.isActive else {
            defaults.removeObject(forKey: Self.storageKey)
            return
        }
        run = stored
        refresh()
        scheduleAlert()
        updateTicking()
    }
}
