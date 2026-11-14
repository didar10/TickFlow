import Foundation
import Testing
import UniformTypeIdentifiers
@testable import TickFlow

@MainActor
struct ExportServiceTests {
    let fixture: ModelFixture
    let exportedAt = date("2026-11-08 09:00")

    init() throws {
        fixture = try ModelFixture()
    }

    private func export(tasks: [TaskItem] = [], lists: [TaskList] = [], habits: [Habit] = []) throws -> [String: Any] {
        let data = try ExportService.makeJSON(tasks: tasks, lists: lists, habits: habits, exportedAt: exportedAt)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func emptyDatabaseGivesValidArchive() throws {
        let json = try export()
        #expect(Set(json.keys) == ["exportedAt", "categories", "tasks", "habits", "timeEntries"])
        #expect((json["categories"] as? [Any])?.isEmpty == true)
        #expect((json["tasks"] as? [Any])?.isEmpty == true)
        #expect((json["habits"] as? [Any])?.isEmpty == true)
        // ISO 8601 в UTC: 09:00 по Москве — 06:00Z.
        #expect(json["exportedAt"] as? String == "2026-11-08T06:00:00Z")
    }

    @Test func exportsCategories() throws {
        let list = fixture.list("Работа", color: "#FF0000")
        let categories = try #require(try export(lists: [list])["categories"] as? [[String: Any]])
        #expect(categories.count == 1)
        #expect(categories[0]["id"] as? String == list.id.uuidString)
        #expect(categories[0]["name"] as? String == "Работа")
        #expect(categories[0]["color"] as? String == "#FF0000")
    }

    @Test func exportsTasksWithSubtasksInOrder() throws {
        let list = fixture.list("Дом")
        let task = fixture.task("Уборка", due: "2026-11-08 18:00", minutes: 90, endDay: nil,
                                priority: .high, repeatRule: .weekly, list: list)
        task.notes = "Кухня"
        task.subtasks.append(Subtask(title: "Пол", isCompleted: false, sortOrder: 1))
        task.subtasks.append(Subtask(title: "Пыль", isCompleted: true, sortOrder: 0))

        let tasks = try #require(try export(tasks: [task])["tasks"] as? [[String: Any]])
        let record = try #require(tasks.first)
        #expect(record["id"] as? String == task.id.uuidString)
        #expect(record["title"] as? String == "Уборка")
        #expect(record["notes"] as? String == "Кухня")
        #expect(record["categoryID"] as? String == list.id.uuidString)
        #expect(record["due"] as? String == "2026-11-08T15:00:00Z")
        #expect(record["hasTime"] as? Bool == true)
        #expect(record["durationMinutes"] as? Int == 90)
        #expect(record["priority"] as? Int == Priority.high.rawValue)
        #expect(record["repeatRule"] as? Int == RepeatRule.weekly.rawValue)
        #expect(record["isCompleted"] as? Bool == false)
        #expect(record["createdAt"] is String)

        let subtasks = try #require(record["subtasks"] as? [[String: Any]])
        #expect(subtasks.map { $0["title"] as? String } == ["Пыль", "Пол"])
        #expect(subtasks.map { $0["isCompleted"] as? Bool } == [true, false])
    }

    @Test func optionalFieldsAreOmittedWhenEmpty() throws {
        let tasks = try #require(try export(tasks: [fixture.task("Без даты")])["tasks"] as? [[String: Any]])
        let record = try #require(tasks.first)
        #expect(record["due"] == nil)
        #expect(record["lastDay"] == nil)
        #expect(record["categoryID"] == nil)
        #expect(record["completedAt"] == nil)
    }

    @Test func multiDayTaskExportsLastDay() throws {
        let task = fixture.task(due: "2026-11-08", endDay: "2026-11-10")
        let record = try #require((try export(tasks: [task])["tasks"] as? [[String: Any]])?.first)
        #expect(record["lastDay"] as? String == "2026-11-09T21:00:00Z")
    }

    @Test func exportsHabitsWithLogsByDay() throws {
        let habit = fixture.habit("Вода", kind: .amount, target: 2000, unit: "мл",
                                  frequency: .specificDays, weekdays: [2, 4], start: "2026-11-01")
        fixture.log(habit, "2026-11-05", value: 1500)
        fixture.log(habit, "2026-11-03", value: 2000)
        fixture.log(habit, "2026-11-04", skipped: true)

        let habits = try #require(try export(habits: [habit])["habits"] as? [[String: Any]])
        let record = try #require(habits.first)
        #expect(record["name"] as? String == "Вода")
        #expect(record["kind"] as? Int == HabitKind.amount.rawValue)
        #expect(record["target"] as? Double == 2000)
        #expect(record["unit"] as? String == "мл")
        #expect(record["frequency"] as? Int == HabitFrequency.specificDays.rawValue)
        #expect(record["weekdays"] as? [Int] == [2, 4])
        #expect(record["startDate"] as? String == "2026-10-31T21:00:00Z")

        let logs = try #require(record["logs"] as? [[String: Any]])
        #expect(logs.map { $0["day"] as? String } == [
            "2026-11-02T21:00:00Z", "2026-11-03T21:00:00Z", "2026-11-04T21:00:00Z",
        ])
        #expect(logs.map { $0["value"] as? Double } == [2000, 0, 1500])
        #expect(logs.map { $0["isSkipped"] as? Bool } == [false, true, false])
    }

    @Test func outputIsStable() throws {
        let tasks = [fixture.task("A", due: "2026-11-08"), fixture.task("B")]
        let first = try ExportService.makeJSON(tasks: tasks, lists: [], habits: [], exportedAt: exportedAt)
        let second = try ExportService.makeJSON(tasks: tasks, lists: [], habits: [], exportedAt: exportedAt)
        #expect(first == second)
        #expect(String(decoding: first, as: UTF8.self).contains("\n"))
    }

    @Test func exportFileWritesJSONForSharing() async throws {
        let file = ExportFile(fileName: "TickFlow-test-\(UUID().uuidString).json") { [exportedAt] in
            try ExportService.makeJSON(tasks: [], lists: [], habits: [], exportedAt: exportedAt)
        }
        let shared = try await file.exported(as: .json)
        #expect(shared == (try file.makeData()))
    }

    @Test func exportsTimeTrackingFields() throws {
        let list = fixture.list("Работа")
        list.tracksTimeByDefault = true
        let task = fixture.task("Отчёт", list: list)
        task.trackingOverride = false
        task.estimateMinutes = 150
        let late = TimeEntry(start: date("2026-11-08 10:00"), end: date("2026-11-08 10:25"), kind: .timer,
                             status: .interrupted, task: task)
        let early = TimeEntry(start: date("2026-11-08 08:00"), end: date("2026-11-08 08:05"), kind: .breakTime)
        fixture.context.insert(late)
        fixture.context.insert(early)

        let data = try ExportService.makeJSON(tasks: [task], lists: [list], habits: [], timeEntries: [late, early],
                                              exportedAt: exportedAt)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        let category = try #require((json["categories"] as? [[String: Any]])?.first)
        #expect(category["tracksTimeByDefault"] as? Bool == true)
        let record = try #require((json["tasks"] as? [[String: Any]])?.first)
        #expect(record["trackingOverride"] as? Bool == false)
        #expect(record["estimateMinutes"] as? Int == 150)

        let entries = try #require(json["timeEntries"] as? [[String: Any]])
        #expect(entries.count == 2)
        #expect(entries[0]["kind"] as? Int == TimeEntryKind.breakTime.rawValue)
        #expect(entries[0]["taskID"] == nil)
        #expect(entries[1]["taskID"] as? String == task.id.uuidString)
        #expect(entries[1]["status"] as? Int == TimeEntryStatus.interrupted.rawValue)
        #expect(entries[1]["start"] as? String == "2026-11-08T07:00:00Z")
    }
}
