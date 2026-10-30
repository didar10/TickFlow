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

        // Задачи со временем на завтра и послезавтра, чтобы таймлайн не был пустым.
        let timed: [(day: Int, hour: Int, minutes: Int, title: String, list: TaskList)] = [
            (1, 7, 60, "Утренняя пробежка", personal),
            (1, 9, 120, "Закупка продуктов", personal),
            (1, 12, 60, "Ответить на письма", inbox),
            (1, 13, 240, "Обсудить план с клиентом", work),
            (2, 8, 240, "Подготовить презентацию", work),
            (2, 13, 60, "Встреча по проекту", work),
            (2, 14, 120, "Забрать посылку", personal)
        ]
        for (index, item) in timed.enumerated() {
            guard
                let day = calendar.date(byAdding: .day, value: item.day, to: today),
                let start = calendar.date(byAdding: .hour, value: item.hour, to: day)
            else { continue }
            context.insert(
                TaskItem(
                    title: item.title,
                    dueDate: start,
                    hasTime: true,
                    durationMinutes: item.minutes,
                    list: item.list,
                    sortOrder: samples.count + index
                )
            )
        }
        try? context.save()
    }
}
