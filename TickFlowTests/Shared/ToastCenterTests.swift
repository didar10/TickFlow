import Foundation
import Testing
@testable import TickFlow

@MainActor
struct ToastCenterTests {
    let sleeper = ManualSleeper()
    let toasts: ToastCenter

    init() {
        toasts = ToastCenter(sleep: sleeper.sleep)
    }

    @Test func showSetsCurrentToast() {
        toasts.show("Задача удалена")
        #expect(toasts.current?.message == "Задача удалена")
        #expect(toasts.current?.undo == nil)
        #expect(toasts.current?.showsSaved == false)
    }

    @Test func newToastReplacesOld() {
        toasts.show("Первый")
        let firstID = toasts.current?.id
        toasts.show("Второй")
        #expect(toasts.current?.message == "Второй")
        #expect(toasts.current?.id != firstID)
    }

    @Test func undoRunsOnceAndShowsConfirmation() {
        var undoCount = 0
        toasts.show("Задача удалена") { undoCount += 1 }
        #expect(toasts.current?.undo != nil)

        toasts.performUndo()
        #expect(undoCount == 1)
        #expect(toasts.current?.message == "Изменение отменено")
        #expect(toasts.current?.undo == nil)

        // У подтверждения нет отмены — повторное нажатие ничего не делает.
        toasts.performUndo()
        #expect(undoCount == 1)
    }

    @Test func undoWithoutActionDoesNothing() {
        toasts.show("Сохранено")
        let id = toasts.current?.id
        toasts.performUndo()
        #expect(toasts.current?.id == id)
    }

    @Test func dismissClearsToast() {
        toasts.show("Сообщение")
        toasts.dismiss()
        #expect(toasts.current == nil)
    }

    @Test func timersMarkSavedThenDismiss() async {
        toasts.show("Сообщение")
        await settle(until: { sleeper.pendingCount == 2 })
        #expect(Set(sleeper.requested) == [ToastCenter.savedDelay, ToastCenter.dismissDelay])
        #expect(ToastCenter.savedDelay == .milliseconds(900))
        #expect(ToastCenter.dismissDelay == .seconds(4.5))

        sleeper.resume(ToastCenter.savedDelay)
        await settle(until: { toasts.current?.showsSaved == true })
        #expect(toasts.current?.showsSaved == true)

        sleeper.resume(ToastCenter.dismissDelay)
        await settle(until: { toasts.current == nil })
        #expect(toasts.current == nil)
    }

    @Test func staleTimerDoesNotDismissNewToast() async {
        toasts.show("Первый")
        await settle(until: { sleeper.pendingCount == 2 })
        toasts.show("Второй")
        await settle(until: { sleeper.pendingCount == 4 })

        // Таймеры первого тоста срабатывают раньше — но он уже заменён.
        sleeper.resume(ToastCenter.savedDelay)
        sleeper.resume(ToastCenter.dismissDelay)
        await settle()
        #expect(toasts.current?.message == "Второй")
        #expect(toasts.current?.showsSaved == false)

        sleeper.resumeAll()
        await settle(until: { toasts.current == nil })
        #expect(toasts.current == nil)
    }
}
