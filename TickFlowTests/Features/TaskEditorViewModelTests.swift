import Foundation
import Testing
@testable import TickFlow

/// Сегодня — воскресенье 08.11.2026, 09:00.
@MainActor
struct TaskEditorViewModelTests {
    let fixture: ModelFixture
    let clock = FixedClock("2026-11-08 09:00")
    let toasts = ToastCenter(sleep: { _ in try await Task.sleep(for: .seconds(3600)) })
    let repository: FakeTaskRepository
    let work: TaskList
    let home: TaskList

    init() throws {
        fixture = try ModelFixture()
        work = fixture.list("Работа", color: "#111111")
        home = fixture.list("Дом", color: "#222222")
        repository = FakeTaskRepository(lists: [work, home])
    }

    private func editor(_ request: TaskEditorRequest, settings: AppSettings = AppSettings()) -> TaskEditorViewModel {
        TaskEditorViewModel(
            request: request, settings: settings, tasks: repository, lists: repository,
            toasts: toasts, clock: clock
        )
    }

    private func newTask(day: String? = "2026-11-08", start: Int? = nil, endDay: String? = nil, list: TaskList? = nil) -> TaskEditorViewModel {
        editor(.new(day: day.map { date($0) }, startMinute: start, endDay: endDay.map { date($0) }, list: list))
    }

    private func existing(_ task: TaskItem) -> TaskEditorViewModel {
        repository.insert([task])
        return editor(.edit(task))
    }

    // MARK: - Новая задача

    @Test func newTaskStartsInQuickModeWithFirstCategory() {
        let editor = newTask()
        #expect(editor.mode == .quick)
        #expect(!editor.isEditing)
        #expect(editor.focusRequest == .title)
        #expect(editor.categoryName == "Работа")
        #expect(!editor.isCategoryExplicit)
        #expect(editor.categories.filter(\.isSelected).map(\.name) == ["Работа"])
        #expect(!editor.canSave)
    }

    @Test func requestedCategoryWins() {
        #expect(newTask(list: home).categoryName == "Дом")
    }

    @Test func newTaskWithoutTimeHasNoReminder() {
        let editor = newTask()
        #expect(editor.hasDate)
        #expect(!editor.schedule.hasTime)
        #expect(editor.schedule.reminder == .none)
        #expect(editor.whenShort == "Сегодня")
    }

    @Test func newTaskWithTimeUsesDefaults() {
        var settings = AppSettings()
        settings.defaultTaskDuration = 45
        settings.defaultReminder = .hourBefore
        let editor = editor(.new(day: date("2026-11-09"), startMinute: 600), settings: settings)

        #expect(editor.schedule.hasTime)
        #expect(editor.schedule.startMinute == 600)
        #expect(editor.schedule.endMinute == 645)
        #expect(editor.schedule.reminder == .hourBefore)
        #expect(editor.schedule.isPeriod)
        #expect(editor.whenShort == "Завтра, 10:00")
        #expect(editor.whenFull == "Завтра, 10:00 – 10:45")
    }

    @Test func blankTitleCannotBeSaved() {
        let editor = newTask()
        editor.title = "   "
        editor.save()
        #expect(repository.savedDrafts.isEmpty)
        #expect(!editor.isFinished)
    }

    @Test func savingNewTaskCreatesItAndOffersUndo() throws {
        let editor = newTask(start: 600)
        editor.title = "  Созвон  "
        editor.notes = "Повестка"
        editor.selectPriority(.high)
        editor.selectCategory(home.id)
        editor.save()

        let draft = try #require(repository.savedDrafts.first?.draft)
        #expect(repository.savedDrafts.first?.task == nil)
        #expect(draft.title == "Созвон")
        #expect(draft.notes == "Повестка")
        #expect(draft.dueDate == date("2026-11-08 10:00"))
        #expect(draft.hasTime)
        #expect(draft.durationMinutes == 60)
        #expect(draft.endDay == nil)
        #expect(draft.priority == .high)
        #expect(draft.list === home)
        #expect(editor.isFinished)
        #expect(toasts.current?.message == "Добавлено · Сегодня, 10:00")

        toasts.performUndo()
        #expect(repository.deletedIDs.count == 1)
        #expect(repository.tasks.isEmpty)
    }

    @Test func savingUndatedTask() throws {
        let editor = newTask(day: nil)
        editor.title = "Когда-нибудь"
        editor.save()

        let draft = try #require(repository.savedDrafts.first?.draft)
        #expect(draft.dueDate == nil)
        #expect(!draft.hasTime)
        #expect(draft.reminder == .none)
        #expect(draft.repeatRule == .never)
        #expect(toasts.current?.message == "Добавлено · Без даты")
    }

    @Test func savingOverlappingTaskWarnsInToast() {
        repository.insert([fixture.task("Обед", due: "2026-11-08 10:30")])
        let editor = newTask(start: 600)
        editor.title = "Созвон"
        editor.save()
        #expect(toasts.current?.message == "Добавлено · Сегодня, 10:00 · Пересекается с «Обед»")
    }

    @Test func multiDayRequest() throws {
        let editor = newTask(day: "2026-11-08", endDay: "2026-11-10")
        #expect(editor.whenShort == "8 – 10 нояб.")
        #expect(editor.whenFull == "8 – 10 нояб.")
        editor.title = "Отпуск"
        editor.save()
        let draft = try #require(repository.savedDrafts.first?.draft)
        #expect(draft.dueDate == date("2026-11-08"))
        #expect(draft.endDay == date("2026-11-10"))
    }

    @Test func submitTitleSavesInQuickModeAndMovesFocusInFull() {
        let quick = newTask()
        quick.title = "Быстро"
        quick.submitTitle()
        #expect(repository.savedDrafts.count == 1)

        let full = newTask()
        full.openFullScreen()
        #expect(full.mode == .full)
        full.title = "Подробно"
        full.submitTitle()
        #expect(full.focusRequest == .notes)
        #expect(repository.savedDrafts.count == 1)
    }

    @Test func backDiscardsEmptyAndSavesFilled() {
        let empty = newTask()
        empty.back()
        #expect(empty.isFinished)
        #expect(repository.savedDrafts.isEmpty)

        let filled = newTask()
        filled.title = "Есть название"
        filled.back()
        #expect(repository.savedDrafts.count == 1)

        let discarded = newTask()
        discarded.title = "Черновик"
        discarded.discard()
        #expect(discarded.isFinished)
        #expect(repository.savedDrafts.count == 1)
    }

    // MARK: - Подзадачи

    @Test func subtaskEditing() throws {
        let editor = newTask()
        editor.newSubtaskTitle = "   "
        #expect(!editor.canAddSubtask)
        editor.addSubtask()
        #expect(editor.subtasks.isEmpty)

        editor.newSubtaskTitle = " Купить молоко "
        editor.addSubtask()
        editor.newSubtaskTitle = "Хлеб"
        editor.addSubtask()
        #expect(editor.subtasks.map(\.title) == ["Купить молоко", "Хлеб"])
        #expect(editor.newSubtaskTitle == "")
        #expect(editor.focusRequest == .subtask)

        let first = try #require(editor.subtasks.first?.id)
        editor.toggleSubtask(first)
        #expect(editor.subtaskCount == "1 из 2")
        editor.renameSubtask(first, to: "Молоко")
        editor.deleteSubtask(editor.subtasks[1].id)
        #expect(editor.subtasks.map(\.title) == ["Молоко"])
        #expect(editor.subtasks.map(\.isCompleted) == [true])
    }

    @Test func saveIncludesPendingSubtaskAndDropsBlankOnes() throws {
        let editor = newTask()
        editor.title = "Покупки"
        editor.newSubtaskTitle = "Сыр"
        editor.addSubtask()
        editor.renameSubtask(editor.subtasks[0].id, to: "  ")
        editor.newSubtaskTitle = "Яблоки"
        editor.save()

        let draft = try #require(repository.savedDrafts.first?.draft)
        #expect(draft.subtasks.map(\.title) == ["Яблоки"])
    }

    // MARK: - Существующая задача

    @Test func editorLoadsExistingTask() {
        let task = fixture.task("Отчёт", due: "2026-11-09 14:00", minutes: 90, priority: .medium,
                                reminder: .tenMinutesBefore, repeatRule: .weekly, list: home)
        fixture.addSubtasks([("Данные", true), ("Текст", false)], to: task)
        let editor = existing(task)

        #expect(editor.mode == .full)
        #expect(editor.isEditing)
        #expect(editor.focusRequest == nil)
        #expect(editor.title == "Отчёт")
        #expect(editor.priority == .medium)
        #expect(editor.categoryName == "Дом")
        #expect(editor.subtasks.map(\.title) == ["Данные", "Текст"])
        #expect(editor.schedule.startMinute == 840)
        #expect(editor.schedule.endMinute == 930)
        #expect(editor.schedule.isPeriod)
        #expect(editor.hasReminderOrRepeat)
        #expect(editor.whenFull == "Завтра, 14:00 – 15:30")
        #expect(editor.priorities.map(\.priority) == [.high, .medium, .low, .none])
        #expect(editor.priorities.filter(\.isSelected).map(\.priority) == [.medium])
    }

    @Test func taskEndingAtMidnightShowsAs2400() {
        let editor = existing(fixture.task(due: "2026-11-08 23:00", minutes: 60))
        #expect(editor.schedule.endDay == date("2026-11-08"))
        #expect(editor.schedule.endMinute == 1440)
        #expect(!editor.schedule.isMultiDay(calendar: TestCalendar.moscow))
    }

    @Test func undatedTaskUsesDefaultTimes() {
        let editor = existing(fixture.task("Без даты"))
        #expect(!editor.hasDate)
        #expect(editor.whenFull == "Дата и напоминание")
        #expect(editor.whenShort == "")
    }

    @Test func unchangedTaskClosesWithoutSaving() {
        let editor = existing(fixture.task("Отчёт", due: "2026-11-09 14:00"))
        editor.save()
        #expect(editor.isFinished)
        #expect(repository.savedDrafts.isEmpty)
        #expect(toasts.current == nil)
    }

    @Test func editedTaskIsSavedWithUndo() throws {
        let task = fixture.task("Отчёт", due: "2026-11-09 14:00")
        let editor = existing(task)
        editor.title = "Итоговый отчёт"
        editor.save()

        #expect(repository.savedDrafts.count == 1)
        #expect(repository.savedDrafts[0].task === task)
        #expect(repository.savedDrafts[0].draft.title == "Итоговый отчёт")
        #expect(editor.isFinished)
        #expect(toasts.current?.message == "Изменения сохранены")

        toasts.performUndo()
        #expect(repository.restoredIDs == [task.id])
    }

    @Test func togglingCompletionGoesThroughRepository() {
        let task = fixture.task("Отчёт", due: "2026-11-09 14:00", repeatRule: .daily)
        let next = fixture.task("Отчёт", due: "2026-11-10 14:00", repeatRule: .daily)
        repository.nextOccurrence = next
        let editor = existing(task)

        editor.toggleCompleted()
        editor.save()

        #expect(repository.completions.map(\.isCompleted) == [true])
        // Флаг выполнения не уходит в черновик — его выставляет `setCompleted`.
        #expect(repository.savedDrafts.first?.draft.isCompleted == false)

        toasts.performUndo()
        #expect(repository.deletedIDs == [next.id])
        #expect(repository.restoredIDs == [task.id])
    }

    @Test func changingScheduleOfRecurringTaskAsksForScope() throws {
        let task = fixture.task("Пробежка", due: "2026-11-09 07:00", repeatRule: .daily)
        let editor = existing(task)
        editor.openPicker()
        let picker = try #require(editor.picker)
        picker.shiftStartTime(by: 60)
        picker.apply()
        #expect(editor.picker == nil)

        editor.save()
        guard case let .recurring(message) = editor.dialog else {
            Issue.record("Ожидался вопрос о серии, а не \(String(describing: editor.dialog))")
            return
        }
        #expect(message == "«Пробежка» повторяется (каждый день). К чему применить изменение?")
        #expect(repository.savedDrafts.isEmpty)

        editor.resolveRecurring(.thisOccurrence)
        #expect(editor.dialog == nil)
        #expect(repository.savedDrafts.count == 2)
        #expect(repository.savedDrafts[1].draft.dueDate == date("2026-11-09 08:00"))
        #expect(repository.savedDrafts[1].draft.repeatRule == .never)
        #expect(toasts.current?.message == "Изменения сохранены (только это вхождение)")
    }

    @Test func changingOnlyTitleOfRecurringTaskDoesNotAsk() {
        let editor = existing(fixture.task("Пробежка", due: "2026-11-09 07:00", repeatRule: .daily))
        editor.title = "Утренняя пробежка"
        editor.save()
        #expect(editor.dialog == nil)
        #expect(repository.savedDrafts.count == 1)
    }

    @Test func movingIntoBusySlotAsksToConfirm() throws {
        repository.insert([fixture.task("Обед", due: "2026-11-09 13:00")])
        let editor = existing(fixture.task("Звонок", due: "2026-11-09 11:00"))
        editor.openPicker()
        try #require(editor.picker).shiftStartTime(by: 150)
        try #require(editor.picker).apply()

        editor.save()
        guard case let .conflict(message) = editor.dialog else {
            Issue.record("Ожидалось предупреждение о пересечении")
            return
        }
        #expect(message == "«Звонок» пересекается с «Обед» (13:00 – 14:00).")

        editor.cancelDialog()
        #expect(editor.dialog == nil)
        #expect(repository.savedDrafts.isEmpty)

        editor.save()
        editor.confirmConflict()
        #expect(repository.savedDrafts.count == 1)
        #expect(editor.isFinished)
    }

    @Test func recurringScopeIsKeptThroughConflictConfirmation() throws {
        repository.insert([fixture.task("Обед", due: "2026-11-09 13:00")])
        let editor = existing(fixture.task("Пробежка", due: "2026-11-09 07:00", repeatRule: .daily))
        editor.openPicker()
        try #require(editor.picker).shiftStartTime(by: 360)
        try #require(editor.picker).apply()

        editor.save()
        editor.resolveRecurring(.thisOccurrence)
        guard case .conflict = editor.dialog else {
            Issue.record("Ожидалось предупреждение о пересечении")
            return
        }
        editor.confirmConflict()
        // Серия продолжена отдельной задачей — значит, область «только это» сохранилась.
        #expect(repository.savedDrafts.count == 2)
    }

    @Test func invalidScheduleBlocksSave() throws {
        let editor = existing(fixture.task("Отчёт", due: "2026-11-09 14:00"))
        editor.openPicker()
        let picker = try #require(editor.picker)
        picker.tab = .period
        picker.shiftEndTime(by: -60)
        #expect(!picker.canApply)
        editor.closePicker()
        #expect(editor.picker == nil)
        #expect(editor.canSave)
    }

    // MARK: - Меню «Ещё»

    @Test func duplicateWithUndo() {
        let task = fixture.task("Отчёт")
        let editor = existing(task)
        editor.duplicate()
        #expect(repository.duplicatedIDs == [task.id])
        #expect(toasts.current?.message == "Создана копия")

        toasts.performUndo()
        #expect(repository.deletedIDs.count == 1)
        #expect(repository.deletedIDs.first != task.id)
    }

    @Test func deleteAsksThenDeletesWithUndo() {
        let task = fixture.task("Отчёт")
        let editor = existing(task)
        editor.requestDelete()
        guard case .delete = editor.dialog else {
            Issue.record("Ожидался вопрос об удалении")
            return
        }

        editor.confirmDelete()
        #expect(repository.deletedIDs == [task.id])
        #expect(editor.isFinished)
        #expect(toasts.current?.message == "Задача удалена")

        toasts.performUndo()
        #expect(repository.restoredIDs == [task.id])
    }

    @Test func dialogIdentifiers() {
        #expect(TaskEditorViewModel.Dialog.delete.id == "delete")
        #expect(TaskEditorViewModel.Dialog.conflict(message: "").id == "conflict")
        #expect(TaskEditorViewModel.Dialog.recurring(message: "").id == "recurring")
    }
}
