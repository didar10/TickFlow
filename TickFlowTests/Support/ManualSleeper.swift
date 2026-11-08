import Foundation
import Testing

/// Задержка, которая заканчивается, только когда тест её отпустит. Заменяет `Task.sleep` в таймерах.
@MainActor
final class ManualSleeper {
    private var pending: [(duration: Duration, continuation: CheckedContinuation<Void, Never>)] = []
    /// Все запрошенные задержки по порядку.
    private(set) var requested: [Duration] = []

    var pendingCount: Int { pending.count }

    var sleep: @Sendable (Duration) async throws -> Void {
        { [self] duration in await self.wait(duration) }
    }

    private func wait(_ duration: Duration) async {
        await withCheckedContinuation { continuation in
            requested.append(duration)
            pending.append((duration, continuation))
        }
    }

    /// Отпускает самую раннюю задержку с такой длительностью.
    func resume(_ duration: Duration, sourceLocation: SourceLocation = #_sourceLocation) {
        guard let index = pending.firstIndex(where: { $0.duration == duration }) else {
            Issue.record("Нет ожидающей задержки \(duration)", sourceLocation: sourceLocation)
            return
        }
        pending.remove(at: index).continuation.resume()
    }

    func resumeAll() {
        let all = pending
        pending.removeAll()
        all.forEach { $0.continuation.resume() }
    }
}

/// Даёт задачам на главном акторе выполниться до следующей точки ожидания.
@MainActor
func settle(until condition: () -> Bool = { false }, iterations: Int = 50) async {
    for _ in 0..<iterations {
        if condition() { return }
        await Task.yield()
    }
}
