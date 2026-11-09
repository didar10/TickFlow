import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Выгрузка всех данных в JSON. Модели переводятся в простые структуры,
/// чтобы файл не зависел от внутреннего устройства базы.
enum ExportService {
    struct Archive: Encodable {
        let exportedAt: Date
        let categories: [CategoryRecord]
        let tasks: [TaskRecord]
        let habits: [HabitRecord]
        let timeEntries: [TimeEntryRecord]
    }

    struct CategoryRecord: Encodable {
        let id: UUID
        let name: String
        let color: String
        let tracksTimeByDefault: Bool
    }

    struct TaskRecord: Encodable {
        let id: UUID
        let title: String
        let notes: String
        let categoryID: UUID?
        let due: Date?
        let hasTime: Bool
        let durationMinutes: Int
        let lastDay: Date?
        let priority: Int
        let repeatRule: Int
        let isCompleted: Bool
        let completedAt: Date?
        let createdAt: Date
        let trackingOverride: Bool?
        let estimateMinutes: Int?
        let subtasks: [SubtaskRecord]
    }

    struct SubtaskRecord: Encodable {
        let title: String
        let isCompleted: Bool
    }

    struct HabitRecord: Encodable {
        let id: UUID
        let name: String
        let kind: Int
        let target: Double
        let unit: String
        let frequency: Int
        let weekdays: [Int]
        let timesPerWeek: Int
        let startDate: Date
        let logs: [LogRecord]
    }

    struct TimeEntryRecord: Encodable {
        let id: UUID
        let taskID: UUID?
        let start: Date
        let end: Date
        let kind: Int
        let status: Int
    }

    struct LogRecord: Encodable {
        let day: Date
        let value: Double
        let isSkipped: Bool
    }

    @MainActor
    static func makeJSON(
        tasks: [TaskItem],
        lists: [TaskList],
        habits: [Habit],
        timeEntries: [TimeEntry] = [],
        exportedAt: Date = .now
    ) throws -> Data {
        let categories: [CategoryRecord] = lists.map {
            CategoryRecord(id: $0.id, name: $0.name, color: $0.colorHex, tracksTimeByDefault: $0.tracksTimeByDefault)
        }
        let taskRecords: [TaskRecord] = tasks.map(record)
        let habitRecords: [HabitRecord] = habits.map(record)
        let entryRecords: [TimeEntryRecord] = timeEntries
            .sorted { $0.start < $1.start }
            .map {
                TimeEntryRecord(id: $0.id, taskID: $0.task?.id, start: $0.start, end: $0.end,
                                kind: $0.kindRaw, status: $0.statusRaw)
            }
        let archive = Archive(
            exportedAt: exportedAt, categories: categories, tasks: taskRecords,
            habits: habitRecords, timeEntries: entryRecords
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(archive)
    }

    @MainActor
    private static func record(_ task: TaskItem) -> TaskRecord {
        let subtasks: [SubtaskRecord] = task.subtasks
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { SubtaskRecord(title: $0.title, isCompleted: $0.isCompleted) }
        return TaskRecord(
            id: task.id, title: task.title, notes: task.notes, categoryID: task.list?.id,
            due: task.dueDate, hasTime: task.hasTime, durationMinutes: task.durationMinutes,
            lastDay: task.endDay, priority: task.priorityRaw, repeatRule: task.repeatRaw,
            isCompleted: task.isCompleted, completedAt: task.completedAt, createdAt: task.createdAt,
            trackingOverride: task.trackingOverride, estimateMinutes: task.estimateMinutes,
            subtasks: subtasks
        )
    }

    @MainActor
    private static func record(_ habit: Habit) -> HabitRecord {
        let logs: [LogRecord] = habit.logs
            .sorted { $0.day < $1.day }
            .map { LogRecord(day: $0.day, value: $0.value, isSkipped: $0.isSkipped) }
        return HabitRecord(
            id: habit.id, name: habit.name, kind: habit.kindRaw, target: habit.target, unit: habit.unit,
            frequency: habit.frequencyRaw, weekdays: habit.weekdays, timesPerWeek: habit.timesPerWeek,
            startDate: habit.startDate, logs: logs
        )
    }
}

/// Файл экспорта для `ShareLink`: данные собираются только когда пользователь выбрал, куда отправить.
struct ExportFile: Transferable {
    let fileName: String
    let makeData: @MainActor @Sendable () throws -> Data

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { file in
            let data = try await file.makeData()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(file.fileName)
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
