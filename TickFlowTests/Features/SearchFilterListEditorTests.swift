import Foundation
import Testing
@testable import TickFlow

@MainActor
struct SearchViewModelTests {
    let fixture: ModelFixture
    let repository = FakeTaskRepository()
    let toasts = ToastCenter(sleep: { _ in try await Task.sleep(for: .seconds(3600)) })

    init() throws {
        fixture = try ModelFixture()
    }

    private func search(_ tasks: [TaskItem]) -> SearchViewModel {
        repository.insert(tasks)
        return SearchViewModel(
            tasks: repository, settings: FakeSettingsRepository(), toasts: toasts,
            clock: FixedClock("2026-11-08 09:00")
        )
    }

    @Test func emptyQueryShowsSuggestionsOnly() {
        let search = search([fixture.task("Отчёт")])
        search.query = "   "
        #expect(!search.hasQuery)
        #expect(search.results.isEmpty)
        #expect(!search.showsNoResults)
        #expect(search.suggestions == ["Работа", "Ревью", "Здоровье", "Дела"])
    }

    @Test func matchesTitleNotesAndCategoryCaseInsensitive() {
        let work = fixture.list("Работа")
        let byTitle = fixture.task("Ревью макетов")
        let byNotes = fixture.task("Созвон")
        byNotes.notes = "Обсудить РЕВЬЮ"
        let byCategory = fixture.task("Отчёт", list: work)
        let search = search([byTitle, byNotes, byCategory, fixture.task("Другое")])

        search.query = "ревью"
        #expect(Set(search.results.map(\.title)) == ["Ревью макетов", "Созвон"])

        search.applySuggestion("работа")
        #expect(search.query == "работа")
        #expect(search.results.map(\.title) == ["Отчёт"])
        #expect(search.results.first?.meta == "Без даты · Работа")
    }

    @Test func openTasksComeFirstThenByDue() {
        let search = search([
            fixture.task("Задача поздно", due: "2026-11-12"),
            fixture.task("Задача сделана", due: "2026-11-01", completed: true),
            fixture.task("Задача без даты"),
            fixture.task("Задача рано", due: "2026-11-05"),
        ])
        search.query = "задача"
        #expect(search.results.map(\.title) == ["Задача рано", "Задача поздно", "Задача без даты", "Задача сделана"])
        #expect(search.results.map(\.isOverdue) == [true, false, false, false])
        #expect(search.results.first?.meta == "Чт, 5 нояб. · Без категории")
    }

    @Test func noResults() {
        let search = search([fixture.task("Отчёт")])
        search.query = "хлеб"
        #expect(search.showsNoResults)
        #expect(search.trimmedQueryText == "хлеб")
    }

    @Test func openResult() {
        let task = fixture.task("Отчёт")
        let search = search([task])
        search.open(task.id)
        #expect(search.editorRequest?.task === task)
        search.editorRequest = nil
        search.open(UUID())
        #expect(search.editorRequest == nil)
    }
}

@MainActor
struct FilterSheetViewModelTests {
    let fixture: ModelFixture

    init() throws {
        fixture = try ModelFixture()
    }

    @Test func editsSharedFilter() {
        let work = fixture.list("Работа", color: "#111111")
        let home = fixture.list("Дом", color: "#222222")
        let filter = TaskFilterStore()
        let sheet = FilterSheetViewModel(filter: filter, lists: FakeTaskRepository(lists: [work, home]))

        #expect(sheet.categories.map(\.name) == ["Работа", "Дом"])
        #expect(sheet.statusOptions.map(\.value) == [.all, .open, .completed])

        sheet.toggleCategory(home.id)
        sheet.status = .open
        #expect(sheet.categories.filter(\.isSelected).map(\.name) == ["Дом"])
        #expect(filter.categoryIDs == [home.id])
        #expect(filter.status == .open)
        #expect(sheet.status == .open)

        sheet.reset()
        #expect(!filter.isActive)
        #expect(sheet.categories.allSatisfy { !$0.isSelected })
    }
}

@MainActor
struct ListEditorViewModelTests {
    let fixture: ModelFixture
    let toasts = ToastCenter(sleep: { _ in try await Task.sleep(for: .seconds(3600)) })

    init() throws {
        fixture = try ModelFixture()
    }

    @Test func newCategoryGetsFirstUnusedColor() {
        let used = fixture.list("Работа", color: AppPalette.listColors[0].lowercased())
        let repository = FakeTaskRepository(lists: [used])
        let editor = ListEditorViewModel(list: nil, lists: repository, toasts: toasts)

        #expect(editor.title == "Новая категория")
        #expect(editor.saveTitle == "Добавить")
        #expect(!editor.canDelete)
        #expect(editor.colorHex == AppPalette.listColors[1])
        #expect(editor.symbolName == AppPalette.listSymbols[0])
        #expect(editor.colors == AppPalette.listColors)
        #expect(editor.symbols == AppPalette.listSymbols)
    }

    @Test func allColorsUsedFallsBackToFirst() {
        let lists = AppPalette.listColors.map { fixture.list($0, color: $0) }
        let editor = ListEditorViewModel(list: nil, lists: FakeTaskRepository(lists: lists), toasts: toasts)
        #expect(editor.colorHex == AppPalette.listColors[0])
    }

    @Test func createsTrimmedCategory() throws {
        let repository = FakeTaskRepository()
        let editor = ListEditorViewModel(list: nil, lists: repository, toasts: toasts)
        editor.name = "   "
        #expect(!editor.canSave)
        editor.save()
        #expect(repository.savedListDrafts.isEmpty)

        editor.name = "  Учёба "
        editor.selectColor("#BE5A96")
        editor.selectSymbol("book")
        editor.save()

        let draft = try #require(repository.savedListDrafts.first)
        #expect(draft.list == nil)
        #expect(draft.draft.name == "Учёба")
        #expect(draft.draft.colorHex == "#BE5A96")
        #expect(draft.draft.symbolName == "book")
        #expect(editor.isFinished)
    }

    @Test func editsExistingCategory() {
        let list = fixture.list("Работа", color: "#2A9792")
        let repository = FakeTaskRepository(lists: [list])
        let editor = ListEditorViewModel(list: list, lists: repository, toasts: toasts)

        #expect(editor.title == "Категория")
        #expect(editor.saveTitle == "Сохранить")
        #expect(editor.name == "Работа")
        #expect(editor.colorHex == "#2A9792")
        #expect(editor.canDelete)

        editor.name = "Офис"
        editor.save()
        #expect(repository.savedListDrafts.first?.list === list)
        #expect(list.name == "Офис")
    }

    @Test func deleteWarnsAboutTasks() {
        let empty = fixture.list("Пусто")
        #expect(ListEditorViewModel(list: empty, lists: FakeTaskRepository(), toasts: toasts).deleteMessage == "В категории нет задач.")

        let busy = fixture.list("Работа")
        fixture.task("A", list: busy)
        fixture.task("B", list: busy)
        fixture.task("C", list: busy)
        #expect(
            ListEditorViewModel(list: busy, lists: FakeTaskRepository(), toasts: toasts).deleteMessage
                == "Вместе с категорией удалятся 3 задачи. Это нельзя отменить."
        )
    }

    @Test func deleteAfterConfirmation() {
        let list = fixture.list("Работа")
        let repository = FakeTaskRepository(lists: [list])
        let editor = ListEditorViewModel(list: list, lists: repository, toasts: toasts)
        editor.requestDelete()
        #expect(editor.isDeleteConfirmationPresented)

        editor.confirmDelete()
        #expect(repository.deletedListIDs == [list.id])
        #expect(toasts.current?.message == "Категория «Работа» удалена")
        #expect(editor.isFinished)
    }

    @Test func confirmDeleteWithoutListDoesNothing() {
        let repository = FakeTaskRepository()
        let editor = ListEditorViewModel(list: nil, lists: repository, toasts: toasts)
        editor.confirmDelete()
        #expect(repository.deletedListIDs.isEmpty)
        #expect(!editor.isFinished)
    }
}
