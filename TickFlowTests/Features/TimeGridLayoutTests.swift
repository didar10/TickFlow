import CoreGraphics
import Foundation
import Testing
@testable import TickFlow

struct TimeGridLayoutTests {
    private func item(_ start: Int, _ end: Int) -> TimeGridLayout.Item {
        TimeGridLayout.Item(id: UUID(), start: start, end: end)
    }

    private func placement(_ lane: Int, of count: Int) -> TimeGridLayout.Placement {
        TimeGridLayout.Placement(lane: lane, laneCount: count)
    }

    // MARK: - place

    @Test func emptyInputGivesEmptyLayout() {
        #expect(TimeGridLayout.place([]).isEmpty)
    }

    @Test func singleTaskTakesFullWidth() {
        let a = item(600, 660)
        #expect(TimeGridLayout.place([a]) == [a.id: placement(0, of: 1)])
    }

    @Test func overlappingTasksStandSideBySide() {
        let a = item(600, 660), b = item(630, 690)
        let result = TimeGridLayout.place([b, a])
        #expect(result[a.id] == placement(0, of: 2))
        #expect(result[b.id] == placement(1, of: 2))
    }

    @Test func touchingTasksAreSeparateClusters() {
        let a = item(600, 660), b = item(660, 720)
        let result = TimeGridLayout.place([a, b])
        #expect(result[a.id] == placement(0, of: 1))
        #expect(result[b.id] == placement(0, of: 1))
    }

    @Test func chainReusesFreedLane() {
        // A∩B, B∩C, A не пересекается с C: C встаёт на дорожку A.
        let a = item(600, 660), b = item(650, 720), c = item(700, 760)
        let result = TimeGridLayout.place([c, a, b])
        #expect(result[a.id] == placement(0, of: 2))
        #expect(result[b.id] == placement(1, of: 2))
        #expect(result[c.id] == placement(0, of: 2))
    }

    @Test func clustersDoNotAffectEachOther() {
        let a = item(540, 600), b = item(540, 600), c = item(570, 630)
        let d = item(720, 780)
        let result = TimeGridLayout.place([a, b, c, d])
        #expect(result[a.id]?.laneCount == 3)
        #expect(result[b.id]?.laneCount == 3)
        #expect(result[c.id]?.laneCount == 3)
        #expect(result[d.id] == placement(0, of: 1))
        #expect(Set([a, b, c].compactMap { result[$0.id]?.lane }) == [0, 1, 2])
    }

    @Test func longerTaskGoesFirstOnEqualStart() {
        let short = item(600, 630), long = item(600, 720)
        let result = TimeGridLayout.place([short, long])
        #expect(result[long.id] == placement(0, of: 2))
        #expect(result[short.id] == placement(1, of: 2))
    }

    // MARK: - lanes(for:)

    @Test func allDayBarsDoNotOverlap() {
        let x = TimeGridLayout.Bar(id: UUID(), first: 0, last: 2)
        let y = TimeGridLayout.Bar(id: UUID(), first: 1, last: 3)
        let z = TimeGridLayout.Bar(id: UUID(), first: 3, last: 4)
        let result = TimeGridLayout.lanes(for: [x, y, z])
        #expect(result.count == 2)
        #expect(result.lanes[x.id] == 0)
        #expect(result.lanes[y.id] == 1)
        #expect(result.lanes[z.id] == 0)
    }

    @Test func barsOnSameDayNeedSeparateLanes() {
        // Полоса, заканчивающаяся в день начала следующей, не делит с ней дорожку.
        let x = TimeGridLayout.Bar(id: UUID(), first: 0, last: 1)
        let y = TimeGridLayout.Bar(id: UUID(), first: 1, last: 1)
        let result = TimeGridLayout.lanes(for: [x, y])
        #expect(result.count == 2)
        #expect(TimeGridLayout.lanes(for: []).count == 0)
    }

    // MARK: - TimelineGeometry

    @Test(arguments: [
        (.day, 64, 1, false),
        (.threeDay, 52, 3, false),
        (.week, 52, 7, true),
        (.month, 52, 1, false),
    ] as [(CalendarMode, CGFloat, Int, Bool)])
    func geometryForEachMode(mode: CalendarMode, hourHeight: CGFloat, dayCount: Int, isNarrow: Bool) {
        let geometry = TimelineGeometry(mode: mode)
        #expect(geometry.hourHeight == hourHeight)
        #expect(geometry.dayCount == dayCount)
        #expect(geometry.isNarrow == isNarrow)
        #expect(geometry.contentHeight == hourHeight * 24)
    }

    @Test func minutesToPoints() {
        let geometry = TimelineGeometry(mode: .day)
        #expect(geometry.y(forMinute: 0) == 0)
        #expect(geometry.y(forMinute: 90) == 96)
        #expect(geometry.height(minutes: 15) == 16)
    }

    @Test(arguments: [
        (0, 0), (7, 0), (9, 15), (16, 15), (39, 30), (40, 45), (64, 60), (-16, -15), (-9, -15),
    ] as [(CGFloat, Int)])
    func snappedMinutesRoundsToQuarterHour(dy: CGFloat, expected: Int) {
        #expect(TimelineGeometry(mode: .day).snappedMinutes(forDelta: dy) == expected)
    }

    @Test(arguments: [
        (-10, 0), (0, 0), (31, 0), (32, 30), (688, 630), (64 * 23.6, 1410), (64 * 30, 1410),
    ] as [(CGFloat, Int)])
    func slotMinuteRoundsDownToHalfHourWithinDay(y: CGFloat, expected: Int) {
        #expect(TimelineGeometry(mode: .day).slotMinute(atY: y) == expected)
    }
}
