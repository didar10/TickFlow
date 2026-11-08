import Foundation
import Testing
@testable import TickFlow

@MainActor
struct TaskFilterStoreTests {
    let fixture: ModelFixture
    let work: TaskList
    let home: TaskList
    let openWork: TaskItem
    let doneWork: TaskItem
    let openHome: TaskItem
    let noCategory: TaskItem

    init() throws {
        fixture = try ModelFixture()
        work = fixture.list("Работа")
        home = fixture.list("Дом")
        openWork = fixture.task(list: work)
        doneWork = fixture.task(list: work, completed: true)
        openHome = fixture.task(list: home)
        noCategory = fixture.task()
    }

    private var all: [TaskItem] { [openWork, doneWork, openHome, noCategory] }

    private func matching(_ filter: TaskFilterStore) -> [UUID] {
        all.filter(filter.matches).map(\.id)
    }

    @Test func defaultFilterMatchesEverything() {
        let filter = TaskFilterStore()
        #expect(!filter.isActive)
        #expect(matching(filter) == all.map(\.id))
    }

    @Test(arguments: [
        (TaskFilterStore.Status.all, 4),
        (.open, 3),
        (.completed, 1),
    ])
    func statusFilter(status: TaskFilterStore.Status, count: Int) {
        let filter = TaskFilterStore()
        filter.status = status
        #expect(matching(filter).count == count)
        #expect(filter.isActive == (status != .all))
    }

    @Test func categoryFilterExcludesUncategorized() {
        let filter = TaskFilterStore()
        filter.toggleCategory(work.id)
        #expect(filter.isActive)
        #expect(matching(filter) == [openWork.id, doneWork.id])

        filter.toggleCategory(home.id)
        #expect(matching(filter) == [openWork.id, doneWork.id, openHome.id])
    }

    @Test func categoryAndStatusCombine() {
        let filter = TaskFilterStore()
        filter.toggleCategory(work.id)
        filter.status = .open
        #expect(matching(filter) == [openWork.id])
        filter.status = .completed
        #expect(matching(filter) == [doneWork.id])
    }

    @Test func toggleTwiceRemovesCategory() {
        let filter = TaskFilterStore()
        filter.toggleCategory(work.id)
        filter.toggleCategory(work.id)
        #expect(filter.categoryIDs.isEmpty)
        #expect(!filter.isActive)
    }

    @Test func resetClearsEverything() {
        let filter = TaskFilterStore()
        filter.toggleCategory(home.id)
        filter.status = .completed
        filter.reset()
        #expect(filter.categoryIDs.isEmpty)
        #expect(filter.status == .all)
        #expect(!filter.isActive)
    }
}
