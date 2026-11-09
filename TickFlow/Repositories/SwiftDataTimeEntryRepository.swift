import Foundation
import Observation
import OSLog
import SwiftData

/// Записи времени в SwiftData. Работает с тем же контекстом, что и задачи:
/// удаление задачи обнуляет связь у её записей (`nullify`), сами записи остаются.
@MainActor
@Observable
final class SwiftDataTimeEntryRepository: TimeEntryRepository {
    private(set) var entries: [TimeEntry] = []

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let logger = Logger(subsystem: "com.ahito.TickFlow", category: "TimeEntryRepository")

    init(context: ModelContext) {
        self.context = context
        reload()
    }

    @discardableResult
    func add(_ draft: TimeEntryDraft) -> TimeEntry? {
        guard draft.isValid else { return nil }
        let entry = TimeEntry(start: draft.start, end: draft.end, kind: draft.kind, status: draft.status, task: draft.task)
        context.insert(entry)
        commit()
        return entry
    }

    func update(_ entry: TimeEntry, with draft: TimeEntryDraft) {
        guard draft.isValid else { return }
        entry.task = draft.task
        entry.start = draft.start
        entry.end = draft.end
        entry.status = draft.status
        commit()
    }

    func delete(_ entry: TimeEntry) {
        context.delete(entry)
        commit()
    }

    /// Перечитывает записи: после загрузки примера или удаления задачи из другого репозитория.
    func reload() {
        do {
            entries = try context.fetch(
                FetchDescriptor<TimeEntry>(sortBy: [SortDescriptor(\.start), SortDescriptor(\.createdAt)])
            )
        } catch {
            logger.error("Не удалось загрузить записи времени: \(error.localizedDescription)")
        }
    }

    private func commit() {
        do {
            try context.save()
        } catch {
            logger.error("Не удалось сохранить записи времени: \(error.localizedDescription)")
        }
        reload()
    }
}
