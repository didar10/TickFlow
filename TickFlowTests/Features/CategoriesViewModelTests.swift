import Foundation
import Testing
@testable import TickFlow

@MainActor
struct CategoriesViewModelTests {
    let fixture: ModelFixture
    let toasts = ToastCenter(sleep: { _ in try await Task.sleep(for: .seconds(3600)) })

    init() throws {
        fixture = try ModelFixture()
    }

    // MARK: - Экран категорий

    @Test func rowsShowOpenTasksAndTracking() {
        let work = fixture.list("Работа", color: "#111111")
        work.tracksTimeByDefault = true
        fixture.task("A", list: work)
        fixture.task("B", list: work, completed: true)
        let home = fixture.list("Дом")
        let screen = CategoriesViewModel(lists: FakeTaskRepository(lists: [work, home]))

        #expect(screen.rows.map(\.name) == ["Работа", "Дом"])
        #expect(screen.rows.map(\.openTasks) == ["1 открытая задача", "0 открытых задач"])
        #expect(screen.rows.map(\.tracksTime) == [true, false])
        #expect(screen.rows.first?.colorHex == "#111111")
    }

    @Test func editAndAddOpenEditor() throws {
        let work = fixture.list("Работа")
        let screen = CategoriesViewModel(lists: FakeTaskRepository(lists: [work]))

        screen.edit(work.id)
        #expect(screen.editorRequest?.list === work)
        screen.add()
        #expect(try #require(screen.editorRequest).list == nil)

        screen.editorRequest = nil
        screen.edit(UUID())
        #expect(screen.editorRequest == nil)
    }

    // MARK: - Редактор категории

    @Test func newCategoryWithTrackingIsCreatedAndReported() throws {
        let repository = FakeTaskRepository()
        var saved: TaskList?
        let editor = ListEditorViewModel(list: nil, lists: repository, toasts: toasts) { saved = $0 }
        #expect(!editor.tracksTimeByDefault)
        #expect(editor.trackingFootnote == L10n.Lists.trackingOffFootnote)

        editor.name = "Учёба"
        editor.tracksTimeByDefault = true
        #expect(editor.trackingFootnote == L10n.Lists.trackingOnFootnote)
        editor.save()

        let list = try #require(saved)
        #expect(list.name == "Учёба")
        #expect(list.tracksTimeByDefault)
        #expect(repository.lists.count == 1)
        #expect(toasts.current?.message == "Категория «Учёба» создана")
    }

    @Test func editingCategoryShowsOverridesAndNoCreatedToast() {
        let work = fixture.list("Работа")
        work.tracksTimeByDefault = true
        fixture.task("A", list: work).trackingOverride = false
        fixture.task("B", list: work).trackingOverride = false
        fixture.task("C", list: work).trackingOverride = true
        let editor = ListEditorViewModel(list: work, lists: FakeTaskRepository(lists: [work]), toasts: toasts)

        #expect(editor.trackingFootnote == L10n.Lists.trackingOnFootnote + " 2 задачи настроены иначе.")
        editor.tracksTimeByDefault = false
        #expect(editor.trackingFootnote == L10n.Lists.trackingOffFootnote + " 1 задача настроена иначе.")

        editor.save()
        #expect(toasts.current == nil)
        #expect(!work.tracksTimeByDefault)
    }

    // MARK: - Новая категория из редактора задачи

    @Test func categoryCreatedFromTaskEditorIsSelected() {
        let work = fixture.list("Работа")
        let repository = FakeTaskRepository(lists: [work])
        let editor = TaskEditorViewModel(
            request: .new(day: nil, startMinute: nil, endDay: nil, list: nil), settings: AppSettings(),
            tasks: repository, lists: repository, toasts: toasts, clock: FixedClock("2026-11-08 09:00")
        )
        #expect(!editor.isCategoryExplicit)

        editor.requestNewCategory()
        #expect(editor.isNewCategoryPresented)

        let created = repository.save(TaskListDraft(name: "Спорт", colorHex: "#2A9792", symbolName: "figure.run"), to: nil)
        editor.categoryCreated(created)
        #expect(editor.categoryName == "Спорт")
        #expect(editor.isCategoryExplicit)
    }
}
