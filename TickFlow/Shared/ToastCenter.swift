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
    @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void

    /// Задержку можно подменить в тестах, чтобы не ждать таймеров.
    static let savedDelay: Duration = .milliseconds(900)
    static let dismissDelay: Duration = .seconds(4.5)

    init(sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.sleep = sleep
    }

    /// - Parameter undo: действие для кнопки «Отменить». Без него кнопки нет.
    func show(_ message: String, undo: (() -> Void)? = nil) {
        savedTask?.cancel()
        dismissTask?.cancel()
        let toast = Toast(message: message, undo: undo)
        current = toast

        let sleep = sleep
        savedTask = Task { [weak self] in
            try? await sleep(Self.savedDelay)
            guard !Task.isCancelled, self?.current?.id == toast.id else { return }
            self?.current?.showsSaved = true
        }
        dismissTask = Task { [weak self] in
            try? await sleep(Self.dismissDelay)
            guard !Task.isCancelled, self?.current?.id == toast.id else { return }
            self?.current = nil
        }
    }

    func performUndo() {
        guard let undo = current?.undo else { return }
        current = nil
        undo()
        show(L10n.Toast.changeUndone)
    }

    func dismiss() {
        current = nil
    }
}
