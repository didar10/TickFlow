import Foundation
import Observation

/// Создаёт лист записи времени: режим, задача, начало и конец.
typealias TimeEntryEditorFactory = @MainActor (TimeEntryEditorViewModel.Mode, TaskItem?, Date, Date) -> TimeEntryEditorViewModel

/// Нажатие «Стоп»: вопрос о прерванном фокусе или лист сохранения таймера.
/// Свой экземпляр у каждого места, где есть кнопка «Стоп» (экран фокуса, редактор задачи),
/// потому что листы показывает тот экран, который сейчас наверху.
@MainActor
@Observable
final class FocusStopFlow {
    struct Confirmation: Equatable {
        let minutes: Int
        let total: Int
    }

    var confirmation: Confirmation?
    var timerEntry: TimeEntryEditorViewModel?

    @ObservationIgnored private let focus: FocusEngine
    @ObservationIgnored private let toasts: ToastCenter
    @ObservationIgnored private let makeEntryEditor: TimeEntryEditorFactory

    init(focus: FocusEngine, toasts: ToastCenter, makeEntryEditor: @escaping TimeEntryEditorFactory) {
        self.focus = focus
        self.toasts = toasts
        self.makeEntryEditor = makeEntryEditor
    }

    func stop() {
        let task = focus.task
        switch focus.stop() {
        case .ended:
            break
        case .cycleEnded:
            toasts.show(L10n.Focus.cycleEndedToast)
        case let .confirm(minutes, total):
            confirmation = Confirmation(minutes: minutes, total: total)
        case let .saveTimer(start, end):
            timerEntry = makeEntryEditor(.fromTimer, task, start, end)
        }
    }

    func saveInterrupted() {
        confirmation = nil
        guard let entry = focus.saveInterrupted() else { return }
        toasts.show(L10n.Focus.savedInterruptedToast(max(1, entry.durationMinutes)))
    }

    func discard() {
        confirmation = nil
        focus.discardSession()
    }

    /// «Продолжить»: фокус не останавливался.
    func keepGoing() {
        confirmation = nil
    }

    /// Лист таймера закрыт свайпом без решения — таймер идёт дальше.
    func timerSheetDismissed() {
        guard let timerEntry, !timerEntry.isFinished else {
            self.timerEntry = nil
            return
        }
        timerEntry.cancel()
        self.timerEntry = nil
    }
}
