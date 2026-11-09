import Foundation

/// Подписи фокуса и записей времени, общие для экранов.
enum FocusText {
    static func phase(_ run: FocusRun) -> String {
        if run.mode == .timer { return L10n.Focus.phaseTimer }
        switch run.phase {
        case .focus: return L10n.Focus.phaseFocus
        case .shortBreak: return L10n.Focus.phaseShortBreak
        case .longBreak: return L10n.Focus.phaseLongBreak
        }
    }

    /// «Фокус · Пауза» или «Короткий перерыв · Готов».
    static func phaseWithState(_ run: FocusRun) -> String {
        guard !run.isRunning else { return phase(run) }
        return phase(run) + (run.isReady ? L10n.Focus.readySuffix : L10n.Focus.pausedSuffix)
    }

    static func kind(_ kind: TimeEntryKind) -> String {
        switch kind {
        case .focus: L10n.Focus.kindFocus
        case .timer: L10n.Focus.kindTimer
        case .manual: L10n.Focus.kindManual
        case .breakTime: L10n.Focus.kindBreak
        }
    }

    static func status(_ status: TimeEntryStatus) -> String {
        switch status {
        case .completed: L10n.Focus.statusCompleted
        case .interrupted: L10n.Focus.statusInterrupted
        case .cancelled: L10n.Focus.statusCancelled
        }
    }

    /// «1 ч 10 мин / 2 ч 30 мин» или только потраченное, если оценки нет.
    static func tracked(_ minutes: Int, estimate: Int?) -> String {
        let tracked = DateFormatting.duration(minutes: minutes)
        guard let estimate else { return tracked }
        return tracked + " / " + DateFormatting.duration(minutes: estimate)
    }
}
