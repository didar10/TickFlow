import Foundation

/// Источник текущего времени. В приложении — системные часы, в тестах — фиксированные.
protocol AppClock: Sendable {
    var now: Date { get }
}

struct SystemClock: AppClock {
    var now: Date { .now }
}
