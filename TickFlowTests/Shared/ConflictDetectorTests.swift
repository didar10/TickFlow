import Foundation
import Testing
@testable import TickFlow

@MainActor
struct ConflictDetectorTests {
    let fixture: ModelFixture
    let calendar = TestCalendar.moscow

    init() throws {
        fixture = try ModelFixture()
    }

    private func conflict(_ start: String, _ end: String, excluding id: UUID? = nil, in tasks: [TaskItem]) -> TaskItem? {
        ConflictDetector.conflict(start: date(start), end: date(end), excluding: id, in: tasks, calendar: calendar)
    }

    @Test func overlappingIntervalConflicts() {
        let meeting = fixture.task("Встреча", due: "2026-11-08 10:00", minutes: 60)
        #expect(conflict("2026-11-08 10:30", "2026-11-08 11:30", in: [meeting])?.id == meeting.id)
        #expect(conflict("2026-11-08 09:30", "2026-11-08 10:01", in: [meeting])?.id == meeting.id)
        #expect(conflict("2026-11-08 10:15", "2026-11-08 10:45", in: [meeting])?.id == meeting.id)
        #expect(conflict("2026-11-08 09:00", "2026-11-08 12:00", in: [meeting])?.id == meeting.id)
    }

    @Test func touchingIntervalsDoNotConflict() {
        let meeting = fixture.task(due: "2026-11-08 10:00", minutes: 60)
        #expect(conflict("2026-11-08 11:00", "2026-11-08 12:00", in: [meeting]) == nil)
        #expect(conflict("2026-11-08 09:00", "2026-11-08 10:00", in: [meeting]) == nil)
    }

    @Test func ignoresCompletedMultiDayUntimedAndOtherDays() {
        let tasks = [
            fixture.task(due: "2026-11-08 10:00", completed: true),
            fixture.task(due: "2026-11-08 10:00", endDay: "2026-11-09"),
            fixture.task(due: "2026-11-08"),
            fixture.task(due: "2026-11-09 10:00"),
            fixture.task(),
        ]
        #expect(conflict("2026-11-08 09:00", "2026-11-08 12:00", in: tasks) == nil)
    }

    @Test func excludedTaskIsSkipped() {
        let meeting = fixture.task(due: "2026-11-08 10:00")
        let call = fixture.task(due: "2026-11-08 10:30")
        #expect(conflict("2026-11-08 10:00", "2026-11-08 11:00", excluding: meeting.id, in: [meeting, call])?.id == call.id)
        #expect(conflict("2026-11-08 10:00", "2026-11-08 10:30", excluding: meeting.id, in: [meeting, call]) == nil)
    }

    @Test func invalidOrOvernightIntervalHasNoConflict() {
        let late = fixture.task(due: "2026-11-08 23:00", minutes: 60)
        #expect(conflict("2026-11-08 11:00", "2026-11-08 11:00", in: [late]) == nil)
        #expect(conflict("2026-11-08 12:00", "2026-11-08 11:00", in: [late]) == nil)
        #expect(conflict("2026-11-08 23:30", "2026-11-09 00:30", in: [late]) == nil)
        // Конец ровно в полночь — ещё тот же день.
        #expect(conflict("2026-11-08 23:30", "2026-11-09 00:00", in: [late])?.id == late.id)
    }

    @Test func taskDoesNotConflictWithItself() {
        let meeting = fixture.task(due: "2026-11-08 10:00")
        #expect(ConflictDetector.conflict(for: meeting, in: [meeting], calendar: calendar) == nil)

        let call = fixture.task(due: "2026-11-08 10:30")
        #expect(ConflictDetector.conflict(for: meeting, in: [meeting, call], calendar: calendar)?.id == call.id)
    }

    @Test func untimedCompletedOrMultiDayTaskHasNoConflict() {
        let busy = fixture.task(due: "2026-11-08 10:00", minutes: 600)
        let candidates = [
            fixture.task(due: "2026-11-08"),
            fixture.task(due: "2026-11-08 11:00", completed: true),
            fixture.task(due: "2026-11-08 11:00", endDay: "2026-11-10"),
        ]
        for task in candidates {
            #expect(ConflictDetector.conflict(for: task, in: [busy] + candidates, calendar: calendar) == nil)
        }
    }
}
