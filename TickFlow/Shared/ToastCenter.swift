import Foundation
import Observation

/// Тост внизу экрана: сообщение, отметка «Сохранено» и необязательная отмена.
/// ViewModel показывают тосты через этот объект, View только рисует `current`.
@MainActor
@Observable
final class ToastCenter {
    struct Toast: Identifiable {
        let id = UUID()
        let message: String
        var showsSaved = false
        let undo: (() -> Void)?
    }

    private(set) var current: Toast?

    @ObservationIgnored private var savedTask: Task<Void, Never>?
    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    /// - Parameter undo: действие для кнопки «Отменить». Без него кнопки нет.
    func show(_ message: String, undo: (() -> Void)? = nil) {
        savedTask?.cancel()
        dismissTask?.cancel()
        let toast = Toast(message: message, undo: undo)
        current = toast

        savedTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled, self?.current?.id == toast.id else { return }
            self?.current?.showsSaved = true
        }
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4.5))
            guard !Task.isCancelled, self?.current?.id == toast.id else { return }
            self?.current = nil
        }
    }

    func performUndo() {
        guard let undo = current?.undo else { return }
        current = nil
        undo()
        show("Изменение отменено")
    }

    func dismiss() {
        current = nil
    }
}
