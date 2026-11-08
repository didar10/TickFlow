import CoreGraphics
import Foundation
import Testing
@testable import TickFlow

/// Сегодня — воскресенье 08.11.2026, 09:00. Неделя с понедельника: 02.11–08.11.
@MainActor
struct CalendarViewModelTests {
    let fixture: ModelFixture
    let clock = FixedClock("2026-11-08 09:00")
    let repository = FakeTaskRepository()
    let settings = FakeSettingsRepository()
    let filter = TaskFilterStore()
    let toasts = ToastCenter(sleep: { _ in try await Task.sleep(for: .seconds(3600)) })
    let navigator = AppNavigator()
    private let samples = Counter()

    final class Counter { var value = 0 }

    init() throws {
        fixture = try ModelFixture()
    }

    private func calendar(_ mode: CalendarMode = .week, tasks: [TaskItem] = []) -> CalendarViewModel {
        repository.insert(tasks)
        settings.settings.defaultCalendarMode = mode
        let samples = samples
        return CalendarViewModel(
            tasks: repository, lists: repository, settings: settings, filter: filter, toasts: toasts,
            navigator: navigator, loadSampleData: { samples.value += 1 }, clock: clock
        )
    }

    // MARK: - Вид и навигация

    @Test func opensLastUsedModeOnToday() {
        settings.settings.lastCalendarMode = .threeDay
        let calendar = CalendarViewModel(
            tasks: repository, lists: repository, settings: settings, filter: filter, toasts: toasts,
            navigator: navigator, loadSampleData: {}, clock: clock
        )
        #expect(calendar.mode == .threeDay)
        #expect(calendar.selectedDate == date("2026-11-08"))
    }

    @Test func changingModeIsRemembered() {
        let calendar = calendar(.week)
        calendar.mode = .month
        #expect(settings.settings.lastCalendarMode == .month)
        #expect(calendar.isMonth)

        settings.settings.defaultCalendarMode = .day
        #expect(calendar.preferredMode == .day)
        calendar.applyPreferredMode()
        #expect(calendar.isDay)
    }

    @Test func visibleDaysPerMode() {
        let calendar = calendar(.week)
        #expect(calendar.visibleDays.first == date("2026-11-02"))
        #expect(calendar.visibleDays.last == date("2026-11-08"))
        #expect(calendar.visibleDays.count == 7)

        calendar.mode = .threeDay
        #expect(calendar.visibleDays == [date("2026-11-08"), date("2026-11-09"), date("2026-11-10")])

        calendar.mode = .day
        #expect(calendar.visibleDays == [date("2026-11-08")])
    }

    @Test func weekFollowsFirstWeekday() {
        settings.settings.firstWeekday = 1
        let calendar = calendar(.week)
        #expect(calendar.visibleDays.first == date("2026-11-08"))
        #expect(calendar.columnHeaders.first?.weekday == "Вс")
    }

    @Test func previousAndNextShiftByModeLength() {
        let calendar = calendar(.week)
        calendar.showNext()
        #expect(calendar.selectedDate == date("2026-11-15"))

        calendar.mode = .threeDay
        calendar.showPrevious()
        #expect(calendar.selectedDate == date("2026-11-12"))

        calendar.mode = .day
        calendar.showNext()
        #expect(calendar.selectedDate == date("2026-11-13"))

        calendar.goToToday()
        #expect(calendar.selectedDate == date("2026-11-08"))
    }

    @Test func monthNavigationReturnsToTodayInCurrentMonth() {
        let calendar = calendar(.month)
        calendar.showNext()
        #expect(calendar.selectedDate == date("2026-12-01"))
        calendar.showNext()
        #expect(calendar.selectedDate == date("2027-01-01"))
        calendar.showPrevious()
        calendar.showPrevious()
        #expect(calendar.selectedDate == date("2026-11-08"))
    }

    @Test func horizontalSwipeChangesPeriod() {
        let calendar = calendar(.week)
        calendar.swipe(dx: -80)
        #expect(calendar.selectedDate == date("2026-11-15"))
        calendar.swipe(dx: 80)
        #expect(calendar.selectedDate == date("2026-11-08"))
    }

    @Test func shortOrVerticalSwipeIsIgnored() {
        let calendar = calendar(.week)
        calendar.swipe(dx: -40)
        calendar.swipe(dx: -80, dy: 60)
        #expect(calendar.selectedDate == date("2026-11-08"))
        // Порог по горизонтали: |dx| > 1,5 × |dy|.
        calendar.swipe(dx: -80, dy: 50)
        #expect(calendar.selectedDate == date("2026-11-15"))
    }

    @Test func swipeInDayModeMovesByWeekAndInMonthByMonth() {
        let day = calendar(.day)
        day.swipe(dx: -80)
        #expect(day.selectedDate == date("2026-11-15"))
        day.swipe(dx: 80)
        day.swipe(dx: 80)
        #expect(day.selectedDate == date("2026-11-01"))

        let month = calendar(.month)
        month.swipe(dx: -80)
        #expect(month.selectedDate == date("2026-12-01"))
    }

    @Test func openDaySwitchesToDayMode() {
        let calendar = calendar(.week)
        calendar.openDay(date("2026-11-04 15:00"))
        #expect(calendar.isDay)
        #expect(calendar.selectedDate == date("2026-11-04"))
        #expect(settings.settings.lastCalendarMode == .day)
    }

    // MARK: - Шапка

    @Test func titleAndYear() {
        let calendar = calendar(.week)
        #expect(calendar.title == "Ноябрь")
        #expect(calendar.year == "2026")

        calendar.select(date("2026-11-30"))
        #expect(calendar.title == "Нояб. – Дек.")

        calendar.select(date("2026-12-28"))
        #expect(calendar.title == "Дек. – Янв.")
        #expect(calendar.year == "2027")

        calendar.mode = .day
        #expect(calendar.title == "Декабрь")
        #expect(calendar.year == "2026")
    }

    @Test func modeOptions() {
        #expect(calendar().modeOptions.map(\.value) == [.day, .threeDay, .week, .month])
    }

    @Test func dayLabelMarksToday() {
        let calendar = calendar(.day)
        #expect(calendar.dayLabel == "Воскресенье, 8 ноября · Сегодня")
        calendar.showNext()
        #expect(calendar.dayLabel == "Понедельник, 9 ноября")
    }

    @Test func headersMarkTodaySelectionAndTasks() {
        let calendar = calendar(.day, tasks: [fixture.task(due: "2026-11-05")])
        let strip = calendar.dayStrip
        #expect(strip.count == 7)
        #expect(strip.map(\.weekday).first == "П")
        #expect(strip.filter(\.isToday).map(\.number) == ["8"])
        #expect(strip.filter(\.isSelected).map(\.number) == ["8"])
        #expect(strip.filter(\.hasTasks).map(\.number) == ["5"])

        calendar.mode = .week
        #expect(calendar.isToday(6))
        #expect(!calendar.isToday(0))
        #expect(!calendar.isToday(10))
    }

    // MARK: - Шкала

    @Test func hourLabelsHideMidnightAndNearNow() {
        let calendar = calendar(.week)
        let labels = calendar.hourLabels(now: date("2026-11-08 09:10"))
        #expect(labels.count == 24)
        #expect(labels[0].text == "")
        #expect(labels[9].text == "")
        #expect(labels[10].text == "10:00")
        #expect(labels[8].text == "08:00")

        // Сегодня не на экране — линии «сейчас» нет, подписи не прячутся.
        calendar.showNext()
        #expect(calendar.hourLabels(now: date("2026-11-08 09:10"))[9].text == "09:00")
        #expect(calendar.nowLine(at: date("2026-11-08 09:10")) == nil)
    }

    @Test func nowLinePosition() throws {
        let line = try #require(calendar(.week).nowLine(at: date("2026-11-08 09:10")))
        #expect(line.dayIndex == 6)
        #expect(line.minute == 550)
        #expect(line.label == "09:10")
    }

    @Test func initialScroll() {
        let calendar = calendar(.week)
        #expect(calendar.initialScrollMinute == 400)
        calendar.showNext()
        #expect(calendar.initialScrollMinute == 510)
    }

    @Test func cardsLayOutOverlappingTasks() throws {
        let a = fixture.task("A", due: "2026-11-08 10:00")
        let b = fixture.task("B", due: "2026-11-08 10:30")
        let done = fixture.task("C", due: "2026-11-08 10:15", completed: true)
        let other = fixture.task("D", due: "2026-11-03 15:00", minutes: 30)
        let calendar = calendar(.week, tasks: [a, b, done, other])
        let cards = calendar.cards

        let cardA = try #require(cards.first { $0.id == a.id })
        #expect(cardA.dayIndex == 6)
        #expect(cardA.startMinute == 600)
        #expect(cardA.endMinute == 660)
        #expect(cardA.laneCount == 3)
        #expect(cardA.hasConflict)
        #expect(cardA.time == "10:00")
        #expect(cards.first { $0.id == done.id }?.hasConflict == false)

        let cardD = try #require(cards.first { $0.id == other.id })
        #expect(cardD.dayIndex == 1)
        #expect(cardD.laneCount == 1)
        #expect(!cardD.hasConflict)
    }

    @Test func wideCardsShowTimeRange() {
        let calendar = calendar(.day, tasks: [fixture.task(due: "2026-11-08 10:00", minutes: 90)])
        #expect(calendar.cards.first?.time == "10:00 – 11:30")
    }

    @Test func filterHidesTasks() {
        let work = fixture.list("Работа")
        let calendar = calendar(.week, tasks: [fixture.task(due: "2026-11-08 10:00", list: work), fixture.task(due: "2026-11-08 12:00")])
        filter.toggleCategory(work.id)
        #expect(calendar.isFilterActive)
        #expect(calendar.cards.count == 1)
    }

    @Test func allDayBars() throws {
        let trip = fixture.task("Поездка", due: "2026-11-07", endDay: "2026-11-10")
        let single = fixture.task("Дедлайн", due: "2026-11-08")
        let calendar = calendar(.week, tasks: [trip, single])

        let bars = calendar.bars
        let tripBar = try #require(bars.first { $0.id == trip.id })
        #expect(tripBar.first == 5)
        #expect(tripBar.last == 6)
        #expect(tripBar.isMultiDay)
        #expect(tripBar.title == "Поездка")
        let singleBar = try #require(bars.first { $0.id == single.id })
        #expect(singleBar.first == 6)
        #expect(singleBar.lane != tripBar.lane)
        #expect(calendar.allDayLaneCount == 2)

        // Начало за пределами экрана отмечается стрелкой.
        calendar.mode = .day
        calendar.showNext()
        #expect(calendar.bars.map(\.title) == ["‹ Поездка"])
    }

    // MARK: - Месяц

    @Test func monthCellsWithDots() throws {
        let work = fixture.list("Работа", color: "#123456")
        let tasks = [
            fixture.task("Просрочено", due: "2026-11-05"),
            fixture.task("Сделано", due: "2026-11-05", completed: true),
            fixture.task("Будущее", due: "2026-11-05", list: work),
            fixture.task("Четвёртая", due: "2026-11-05"),
            fixture.task("Потом", due: "2026-11-12", list: work),
        ]
        let calendar = calendar(.month, tasks: tasks)
        let cells = calendar.monthCells

        #expect(cells.count == 42)
        #expect(cells.first?.id == date("2026-10-26"))
        #expect(cells.filter(\.isInMonth).count == 30)
        #expect(cells.filter(\.isToday).map(\.number) == ["8"])
        #expect(cells.filter(\.isSelected).map(\.number) == ["8"])

        let fifth = try #require(cells.first { $0.id == date("2026-11-05") })
        // Прошедший день: невыполненные — красные, выполненные — серые.
        #expect(fifth.dotHexes == ["#E5484D", "#D1D1D6", "#E5484D"])
        #expect(fifth.more == "+1")
        let twelfth = try #require(cells.first { $0.id == date("2026-11-12") })
        #expect(twelfth.dotHexes == ["#123456"])
        #expect(twelfth.more == "")
        #expect(calendar.weekdaySymbols.first == "Пн")
    }

    @Test func agendaSortsAllDayFirst() {
        let tasks = [
            fixture.task("Вечер", due: "2026-11-08 18:00"),
            fixture.task("Утро", due: "2026-11-08 08:00", minutes: 30, priority: .high, completed: true),
            fixture.task("Весь день", due: "2026-11-08"),
            fixture.task("Поездка", due: "2026-11-07", endDay: "2026-11-10"),
            fixture.task("Завтра", due: "2026-11-09 10:00"),
        ]
        let calendar = calendar(.month, tasks: tasks)
        let agenda = calendar.agenda

        #expect(Set(agenda.prefix(2).map(\.title)) == ["Весь день", "Поездка"])
        #expect(agenda.suffix(2).map(\.title) == ["Утро", "Вечер"])
        #expect(agenda.first { $0.title == "Поездка" }?.time == "День 2 из 4")
        #expect(agenda.first { $0.title == "Весь день" }?.time == "Весь день")
        #expect(agenda.first { $0.title == "Утро" }?.time == "08:00 – 08:30")
        #expect(agenda.first { $0.title == "Утро" }?.isUrgent == true)
        #expect(calendar.agendaCount == "1 из 4 выполнено")
        #expect(calendar.agendaTitle == "Сегодня")

        calendar.select(date("2026-11-20"))
        #expect(calendar.agenda.isEmpty)
        #expect(calendar.agendaCount == "")
        #expect(calendar.agendaTitle == "Пятница, 20 ноября")
    }

    // MARK: - Пустые состояния

    @Test func firstRunWithoutTasks() {
        let empty = calendar(.week)
        #expect(empty.isFirstRun)
        empty.mode = .month
        #expect(!empty.isFirstRun)
    }

    @Test func emptyDayInDayMode() {
        let withTasks = calendar(.day, tasks: [fixture.task(due: "2026-11-09")])
        #expect(!withTasks.isFirstRun)
        #expect(withTasks.isDayEmpty)
        withTasks.showNext()
        #expect(!withTasks.isDayEmpty)
    }

    @Test func emptyStateActions() {
        let calendar = calendar()
        calendar.loadSample()
        #expect(samples.value == 1)
        calendar.addFirstHabit()
        #expect(navigator.selectedTab == .habits)
        #expect(navigator.wantsNewHabit)
    }

    // MARK: - Создание и действия

    @Test func plusOnTodaySuggestsNextHour() throws {
        let work = fixture.list("Работа")
        repository.insert([work])
        let calendar = calendar(.week)
        calendar.beginCreatingTask()
        let request = try #require(calendar.editorRequest)
        #expect(request.day == date("2026-11-08"))
        #expect(request.startMinute == 600)
        #expect(request.list === work)

        calendar.showNext()
        calendar.beginCreatingTask()
        #expect(calendar.editorRequest?.startMinute == 540)
    }

    @Test func plusLateEveningIsCappedAt23() {
        clock.now = date("2026-11-08 23:30")
        let calendar = calendar(.day)
        calendar.beginCreatingTask()
        #expect(calendar.editorRequest?.startMinute == 1380)
    }

    @Test func tapOnEmptySlot() {
        let calendar = calendar(.week)
        calendar.beginCreatingTask(dayIndex: 2, y: 52 * 14.6)
        #expect(calendar.editorRequest?.day == date("2026-11-04"))
        #expect(calendar.editorRequest?.startMinute == 870)

        calendar.editorRequest = nil
        calendar.beginCreatingTask(dayIndex: 9, y: 0)
        #expect(calendar.editorRequest == nil)
    }

    @Test func newTaskRequestFromOnboarding() {
        let calendar = calendar()
        calendar.handleNewTaskRequest()
        #expect(calendar.editorRequest == nil)

        navigator.openNewTask()
        #expect(calendar.wantsNewTask)
        calendar.handleNewTaskRequest()
        #expect(calendar.editorRequest != nil)
        #expect(!navigator.wantsNewTask)
    }

    @Test func openToggleAndMenu() throws {
        let task = fixture.task("Отчёт", due: "2026-11-08 10:00")
        let calendar = calendar(tasks: [task])

        calendar.open(task.id)
        #expect(calendar.editorRequest?.task === task)

        calendar.toggle(task.id)
        #expect(repository.completions.map(\.isCompleted) == [true])
        #expect(toasts.current?.message == "Выполнено «Отчёт»")

        calendar.showMenu(task.id)
        let menu = try #require(calendar.menuTask)
        #expect(menu.title == "Отчёт")
        #expect(menu.isCompleted)

        calendar.toggleFromMenu()
        #expect(calendar.menuTask == nil)
        #expect(repository.completions.map(\.isCompleted) == [true, false])

        calendar.showMenu(task.id)
        calendar.deleteFromMenu()
        #expect(repository.deletedIDs == [task.id])
        #expect(toasts.current?.message == "Задача удалена")
        toasts.performUndo()
        #expect(repository.restoredIDs == [task.id])
    }

    @Test func unknownIDsAreIgnored() {
        let calendar = calendar()
        calendar.open(UUID())
        calendar.toggle(UUID())
        calendar.showMenu(UUID())
        calendar.deleteFromMenu()
        calendar.toggleFromMenu()
        #expect(calendar.editorRequest == nil)
        #expect(calendar.menuTask == nil)
        #expect(repository.completions.isEmpty)
    }

    // MARK: - Перетаскивание по времени

    @Test func dragMoveShowsHudGhostAndCommits() throws {
        let task = fixture.task("Созвон", due: "2026-11-08 10:00")
        let calendar = calendar(.week, tasks: [task])

        calendar.beginDrag(task.id, mode: .move)
        #expect(calendar.isDragging)
        calendar.updateDrag(dx: 0, dy: 3, columnWidth: 50)
        #expect(calendar.hud == nil)
        #expect(calendar.ghost == nil)

        calendar.updateDrag(dx: 0, dy: 52, columnWidth: 50)
        #expect(calendar.hud == "Вс  11:00 – 12:00 · 1 ч")
        #expect(calendar.ghost?.startMinute == 600)
        #expect(calendar.cards.first?.startMinute == 660)
        #expect(calendar.cards.first?.isDragging == true)
        #expect(!calendar.dragStepKey.isEmpty)

        calendar.endDrag()
        #expect(!calendar.isDragging)
        #expect(repository.savedDrafts.last?.draft.dueDate == date("2026-11-08 11:00"))
        #expect(repository.savedDrafts.last?.draft.durationMinutes == 60)
        #expect(toasts.current?.message == "Перенесено на 11:00")
        #expect(calendar.cards.first?.isHighlighted == true)

        toasts.performUndo()
        #expect(repository.restoredIDs == [task.id])
    }

    @Test func dragMoveToAnotherDay() {
        let task = fixture.task("Созвон", due: "2026-11-08 10:00")
        let calendar = calendar(.week, tasks: [task])
        calendar.beginDrag(task.id, mode: .move)
        calendar.updateDrag(dx: -100, dy: 0, columnWidth: 50)
        calendar.endDrag()

        #expect(repository.savedDrafts.last?.draft.dueDate == date("2026-11-06 10:00"))
        #expect(toasts.current?.message == "Перенесено на Пт, 6 нояб., 10:00")
    }

    @Test func dragMoveStaysInsideDayAndVisibleDays() {
        let task = fixture.task(due: "2026-11-08 22:30")
        let calendar = calendar(.week, tasks: [task])
        calendar.beginDrag(task.id, mode: .move)
        calendar.updateDrag(dx: 500, dy: 520, columnWidth: 50)
        calendar.endDrag()
        // Не дальше полуночи и не дальше последнего видимого дня.
        #expect(repository.savedDrafts.last?.draft.dueDate == date("2026-11-08 23:00"))
    }

    @Test func dragInDayModeIgnoresHorizontalShift() {
        let task = fixture.task(due: "2026-11-08 10:00")
        let calendar = calendar(.day, tasks: [task])
        calendar.beginDrag(task.id, mode: .move)
        calendar.updateDrag(dx: -300, dy: 64, columnWidth: 50)
        #expect(calendar.hud == "11:00 – 12:00 · 1 ч")
        calendar.endDrag()
        #expect(repository.savedDrafts.last?.draft.dueDate == date("2026-11-08 11:00"))
    }

    @Test func resizeBottomAndTop() {
        let task = fixture.task(due: "2026-11-08 10:00")
        let calendar = calendar(.day, tasks: [task])

        calendar.beginDrag(task.id, mode: .resizeBottom)
        calendar.updateDrag(dx: 0, dy: 32, columnWidth: 50)
        calendar.endDrag()
        #expect(repository.savedDrafts.last?.draft.durationMinutes == 90)
        #expect(toasts.current?.message == "10:00 – 11:30 · 1 ч 30 мин")

        calendar.beginDrag(task.id, mode: .resizeTop)
        calendar.updateDrag(dx: 0, dy: 1000, columnWidth: 50)
        calendar.endDrag()
        // Верхний край не заходит ближе 15 минут к нижнему (теперь 11:30).
        #expect(repository.savedDrafts.last?.draft.dueDate == date("2026-11-08 11:15"))
        #expect(repository.savedDrafts.last?.draft.durationMinutes == 15)
    }

    @Test func holdWithoutMovingOpensMenu() {
        let task = fixture.task("Отчёт", due: "2026-11-08 10:00")
        let calendar = calendar(tasks: [task])
        calendar.beginDrag(task.id, mode: .move)
        calendar.endDrag()
        #expect(calendar.menuTask?.id == task.id)
        #expect(repository.savedDrafts.isEmpty)
    }

    @Test func dragBackToStartChangesNothing() {
        let task = fixture.task(due: "2026-11-08 10:00")
        let calendar = calendar(tasks: [task])
        calendar.beginDrag(task.id, mode: .move)
        calendar.updateDrag(dx: 0, dy: 52, columnWidth: 50)
        calendar.updateDrag(dx: 0, dy: 1, columnWidth: 50)
        calendar.endDrag()
        #expect(repository.savedDrafts.isEmpty)
        #expect(calendar.menuTask == nil)
    }

    @Test func completedTaskCannotBeDragged() {
        let task = fixture.task(due: "2026-11-08 10:00", completed: true)
        let calendar = calendar(tasks: [task])
        calendar.beginDrag(task.id, mode: .move)
        #expect(!calendar.isDragging)
    }

    @Test func cancelDragRestoresCard() {
        let task = fixture.task(due: "2026-11-08 10:00")
        let calendar = calendar(tasks: [task])
        calendar.beginDrag(task.id, mode: .move)
        calendar.updateDrag(dx: 0, dy: 52, columnWidth: 50)
        calendar.cancelDrag()
        #expect(!calendar.isDragging)
        #expect(calendar.cards.first?.startMinute == 600)
        #expect(calendar.dragStepKey == "")
        calendar.endDrag()
        #expect(repository.savedDrafts.isEmpty)
    }

    @Test func dragIntoBusySlotAsksToConfirm() throws {
        let lunch = fixture.task("Обед", due: "2026-11-08 13:00")
        let task = fixture.task("Созвон", due: "2026-11-08 10:00")
        let calendar = calendar(.day, tasks: [lunch, task])

        calendar.beginDrag(task.id, mode: .move)
        calendar.updateDrag(dx: 0, dy: 64 * 3.5, columnWidth: 50)
        #expect(calendar.hud?.hasSuffix(" · Пересекается") == true)
        calendar.endDrag()

        guard case let .conflict(message) = calendar.dialog else {
            Issue.record("Ожидалось предупреждение о пересечении")
            return
        }
        #expect(message == "«Созвон» пересекается с «Обед» (13:00 – 14:00).")
        #expect(calendar.dialog?.id == "conflict")
        #expect(repository.savedDrafts.isEmpty)

        calendar.confirmConflict()
        #expect(repository.savedDrafts.last?.draft.dueDate == date("2026-11-08 13:30"))
    }

    @Test func cancellingConflictKeepsTask() {
        let lunch = fixture.task("Обед", due: "2026-11-08 13:00")
        let task = fixture.task("Созвон", due: "2026-11-08 10:00")
        let calendar = calendar(.day, tasks: [lunch, task])
        calendar.beginDrag(task.id, mode: .move)
        calendar.updateDrag(dx: 0, dy: 64 * 3, columnWidth: 50)
        calendar.endDrag()
        calendar.cancelDialog()
        #expect(calendar.dialog == nil)
        calendar.confirmConflict()
        #expect(repository.savedDrafts.isEmpty)
    }

    @Test func backToBackMoveAddsGapNote() {
        let lunch = fixture.task("Обед", due: "2026-11-08 13:00")
        let task = fixture.task("Созвон", due: "2026-11-08 10:00")
        let calendar = calendar(.day, tasks: [lunch, task])
        calendar.beginDrag(task.id, mode: .move)
        calendar.updateDrag(dx: 0, dy: 64 * 2, columnWidth: 50)
        calendar.endDrag()
        #expect(toasts.current?.message == "Перенесено на 12:00 · Встык с «Обед»")
    }

    @Test func draggingRecurringTaskAsksForScope() {
        let task = fixture.task("Пробежка", due: "2026-11-08 07:00", repeatRule: .daily)
        let calendar = calendar(.day, tasks: [task])
        calendar.beginDrag(task.id, mode: .move)
        calendar.updateDrag(dx: 0, dy: 64, columnWidth: 50)
        calendar.endDrag()

        guard case .recurring = calendar.dialog else {
            Issue.record("Ожидался вопрос о серии")
            return
        }
        #expect(calendar.dialog?.id == "recurring")
        calendar.resolveRecurring(.thisOccurrence)
        #expect(repository.savedDrafts.count == 2)
        #expect(toasts.current?.message == "Перенесено на 08:00 (только это вхождение)")
    }

    // MARK: - Перетаскивание полос «весь день»

    @Test func shiftAllDayTask() {
        let task = fixture.task("Дедлайн", due: "2026-11-08")
        let calendar = calendar(.week, tasks: [task])
        calendar.beginDrag(task.id, mode: .shiftDays)
        calendar.updateDrag(dx: -100, dy: 0, columnWidth: 50)
        #expect(calendar.hud == "Пт, 6 нояб.")
        calendar.endDrag()

        #expect(repository.savedDrafts.last?.draft.dueDate == date("2026-11-06"))
        #expect(repository.savedDrafts.last?.draft.endDay == nil)
        #expect(toasts.current?.message == "Перенесено на Пт, 6 нояб.")
    }

    @Test func extendAllDayTask() {
        let task = fixture.task("Поездка", due: "2026-11-05")
        let calendar = calendar(.week, tasks: [task])
        calendar.beginDrag(task.id, mode: .extendEnd)
        calendar.updateDrag(dx: 100, dy: 0, columnWidth: 50)
        #expect(calendar.hud == "5 – 7 нояб. · 3 дн.")
        calendar.endDrag()

        #expect(repository.savedDrafts.last?.draft.dueDate == date("2026-11-05"))
        #expect(repository.savedDrafts.last?.draft.endDay == date("2026-11-07"))
        #expect(toasts.current?.message == "Теперь 5 – 7 нояб.")
    }

    @Test func extendStartCannotPassEnd() {
        let task = fixture.task(due: "2026-11-04", endDay: "2026-11-06")
        let calendar = calendar(.week, tasks: [task])
        calendar.beginDrag(task.id, mode: .extendStart)
        calendar.updateDrag(dx: 500, dy: 0, columnWidth: 50)
        calendar.endDrag()
        #expect(repository.savedDrafts.last?.draft.dueDate == date("2026-11-06"))
        #expect(repository.savedDrafts.last?.draft.endDay == nil)
    }

    @Test func dialogIdentifiers() {
        #expect(CalendarViewModel.Dialog.conflict(message: "").id == "conflict")
        #expect(CalendarViewModel.Dialog.recurring(message: "").id == "recurring")
    }
}
