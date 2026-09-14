import Foundation
import SwiftData

/// Наполняет базу при первом запуске, чтобы приложение не открывалось пустым.
enum SeedService {

    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<TaskList>()
        let existing = (try? context.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        let inbox = TaskList(name: "Входящие", colorHex: "#3B82F6", symbolName: "tray", sortOrder: 0)
        let work = TaskList(name: "Работа", colorHex: "#F97316", symbolName: "briefcase", sortOrder: 1)
        let personal = TaskList(name: "Личное", colorHex: "#22C55E", symbolName: "house", sortOrder: 2)

        [inbox, work, personal].forEach(context.insert)

        let samples: [TaskItem] = [
            TaskItem(
                title: "Разобрать входящие",
                dueDate: today,
                priority: .medium,
                list: inbox,
                sortOrder: 0
            ),
            TaskItem(
                title: "Ревью пул-реквеста",
                notes: "Проверить миграции SwiftData",
                // От текущего момента, а не от полуночи — иначе задача сразу просрочена.
                dueDate: calendar.date(byAdding: .hour, value: 4, to: .now),
                hasTime: true,
                priority: .high,
                list: work,
                sortOrder: 1
            ),
            TaskItem(
                title: "Записаться к врачу",
                dueDate: calendar.date(byAdding: .day, value: 2, to: today),
                priority: .low,
                list: personal,
                sortOrder: 2
            )
        ]

        samples.forEach(context.insert)
        try? context.save()
    }
}
