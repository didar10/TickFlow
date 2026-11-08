import Foundation
import Testing
@testable import TickFlow

/// Сегодня — воскресенье 08.11.2026, 09:00. Задача по умолчанию: сегодня 10:00–11:00.
@MainActor
struct DateTimePickerViewModelTests {
    let fixture: ModelFixture
    let clock = FixedClock("2026-11-08 09:00")
    var applied: [DateSelection] { box.values }
    private let box = AppliedBox()

    final class AppliedBox { var values: [DateSelection] = [] }

    init() throws {
        fixture = try ModelFixture()
    }

    private func selection(
        day: String? = "2026-11-08",
        endDay: String = "2026-11-08",
        hasTime: Bool = true,
        start: Int = 600,
        end: Int = 660,
        reminder: ReminderOption = .none,
        repeatRule: RepeatRule = .never
    ) -> DateSelection {
        DateSelection(
            day: day.map { date($0) }, endDay: date(endDay), hasTime: hasTime,
            startMinute: start, endMinute: end, reminder: reminder, repeatRule: repeatRule, isPeriod: false
        )
    }

    private func picker(
        _ selection: DateSelection? = nil,
        tasks: [TaskItem] = [],
        excluding id: UUID? = nil,
        firstWeekday: Int = 2
    ) -> DateTimePickerViewModel {
        var settings = AppSettings()
        settings.firstWeekday = firstWeekday
        let box = box
        return DateTimePickerViewModel(
            selection: selection ?? self.selection(),
            format: makeFormat(clock: clock, settings: settings),
            tasks: tasks,
            excluding: id,
            onApply: { box.values.append($0) }
        )
    }

    // MARK: - Открытие

    @Test func opensOnDateTabWithSelectedMonth() {
        let picker = picker(selection(day: "2026-12-20", endDay: "2026-12-20"))
        #expect(picker.tab == .date)
        #expect(!picker.isPeriod)
        #expect(picker.monthTitle == "Декабрь")
        #expect(picker.hasDate)
    }

    @Test func undatedSelectionShowsCurrentMonth() {
        let picker = picker(selection(day: nil, endDay: "2026-01-01"))
        #expect(!picker.hasDate)
        #expect(picker.monthTitle == "Ноябрь")
        #expect(picker.selection.endDay == date("2026-11-08"))
    }

    // MARK: - Пресеты

    @Test func presetsReflectSelection() {
        let picker = picker()
        #expect(picker.presets.map(\.id) == ["today", "tomorrow", "monday", "none"])
        #expect(picker.presets[0].icon == .number("8"))
        #expect(picker.presets.filter(\.isSelected).map(\.id) == ["today"])

        picker.selectPreset("none")
        #expect(picker.selection.day == nil)
        #expect(picker.presets.filter(\.isSelected).map(\.id) == ["none"])
    }

    @Test func tomorrowAndNextMondayPresets() {
        let picker = picker()
        picker.selectPreset("tomorrow")
        #expect(picker.selection.day == date("2026-11-09"))
        // Сегодня воскресенье — следующий понедельник и есть завтра.
        #expect(picker.presets.filter(\.isSelected).map(\.id) == ["tomorrow", "monday"])
    }

    @Test func nextMondayOnMondayIsNextWeek() {
        clock.now = date("2026-11-09 09:00")
        let picker = picker(selection(day: "2026-11-09", endDay: "2026-11-09"))
        picker.selectPreset("monday")
        #expect(picker.selection.day == date("2026-11-16"))
    }

    @Test func selectingDayOnDateTabMakesSingleDay() {
        let picker = picker(selection(endDay: "2026-11-10"))
        picker.select(day: date("2026-12-03 15:00"))
        #expect(picker.selection.day == date("2026-12-03"))
        #expect(picker.selection.endDay == date("2026-12-03"))
        #expect(picker.monthTitle == "Декабрь")
    }

    @Test func selectingDayOnPeriodTabKeepsSpan() {
        let picker = picker()
        picker.tab = .period
        picker.shiftEndDay(by: 2)
        picker.select(day: date("2026-11-20"))
        #expect(picker.selection.day == date("2026-11-20"))
        #expect(picker.selection.endDay == date("2026-11-22"))
    }

    // MARK: - Сетка месяца

    @Test func monthGridStartsOnFirstWeekday() throws {
        // 1 ноября 2026 — воскресенье.
        let mondayFirst = picker(firstWeekday: 2).cells
        #expect(mondayFirst.count == 42)
        #expect(mondayFirst[5].date == nil)
        #expect(mondayFirst[6].label == "1")

        let sundayFirst = picker(firstWeekday: 1).cells
        #expect(sundayFirst.count == 35)
        #expect(sundayFirst[0].label == "1")
        #expect(picker(firstWeekday: 1).weekdaySymbols.first == "В")
    }

    @Test func monthGridMarksTodaySelectionAndPast() throws {
        let picker = picker(selection(day: "2026-11-12", endDay: "2026-11-12"))
        let cells = picker.cells.filter { $0.date != nil }
        #expect(cells.count == 30)
        #expect(cells.filter(\.isToday).map(\.label) == ["8"])
        #expect(cells.filter(\.isSelected).map(\.label) == ["12"])
        #expect(cells.filter(\.isPast).map(\.label) == (1...7).map(String.init))
    }

    @Test func monthNavigation() {
        let picker = picker()
        picker.showNextMonth()
        #expect(picker.monthTitle == "Декабрь")
        picker.showNextMonth()
        #expect(picker.monthTitle == "Январь 2027")
        picker.showPreviousMonth()
        picker.showPreviousMonth()
        picker.showPreviousMonth()
        #expect(picker.monthTitle == "Октябрь")
        // Листание месяца не меняет выбранный день.
        #expect(picker.selection.day == date("2026-11-08"))
    }

    // MARK: - Время во вкладке «Дата»

    @Test func toggleAndClearTime() {
        let picker = picker(selection(hasTime: false))
        #expect(picker.timeValue == "Нет")
        #expect(!picker.isTimeExpanded)

        picker.toggleTime()
        #expect(picker.selection.hasTime)
        #expect(picker.isTimeExpanded)
        #expect(picker.timeValue == "10:00")

        picker.toggleTime()
        #expect(!picker.isTimeExpanded)
        #expect(picker.selection.hasTime)

        picker.clearTime()
        #expect(!picker.selection.hasTime)
        #expect(!picker.hasTimeValue)
    }

    @Test func shiftStartKeepsDurationOnDateTab() {
        let picker = picker()
        picker.shiftStartTime(by: 15)
        #expect(picker.selection.startMinute == 615)
        #expect(picker.selection.endMinute == 675)

        picker.shiftStartTime(by: 2000)
        #expect(picker.selection.startMinute == 1425)
        #expect(picker.selection.endMinute == 1440)

        picker.shiftStartTime(by: -5000)
        #expect(picker.selection.startMinute == 0)
        #expect(picker.selection.endMinute == 60)
    }

    @Test func shiftingStartTurnsTimeOn() {
        let picker = picker(selection(hasTime: false))
        picker.shiftStartTime(by: 15)
        #expect(picker.selection.hasTime)
    }

    // MARK: - Вкладка «Период»

    @Test func switchingToPeriodFillsDateAndTime() {
        let picker = picker(selection(day: nil, hasTime: false, start: 600, end: 540))
        picker.toggleReminder()
        picker.tab = .period

        #expect(picker.isPeriod)
        #expect(picker.selection.day == date("2026-11-08"))
        #expect(picker.selection.hasTime)
        #expect(picker.selection.endMinute == 660)
        #expect(!picker.isReminderExpanded)
    }

    @Test func periodShiftStartKeepsDurationWithinDay() {
        let picker = picker()
        picker.tab = .period
        picker.shiftStartTime(by: 30)
        #expect((picker.selection.startMinute, picker.selection.endMinute) == (630, 690))

        picker.shiftStartTime(by: 1000)
        #expect((picker.selection.startMinute, picker.selection.endMinute) == (1380, 1440))
    }

    @Test func periodShiftEndIsClamped() {
        let picker = picker()
        picker.tab = .period
        picker.shiftEndTime(by: 1000)
        #expect(picker.selection.endMinute == 1440)
        picker.shiftEndTime(by: -5000)
        #expect(picker.selection.endMinute == 15)
    }

    @Test func periodDays() {
        let picker = picker()
        picker.tab = .period
        picker.shiftEndDay(by: 2)
        #expect(picker.selection.endDay == date("2026-11-10"))
        #expect(picker.durationLabel == "3 дн.")

        picker.shiftStartDay(by: 1)
        #expect(picker.selection.day == date("2026-11-09"))
        #expect(picker.selection.endDay == date("2026-11-11"))

        // Конец не уходит раньше начала.
        picker.shiftEndDay(by: -10)
        #expect(picker.selection.endDay == date("2026-11-09"))
        #expect(!picker.isEndDayBeforeStart)
    }

    @Test func invalidPeriodCannotBeApplied() {
        let picker = picker()
        picker.tab = .period
        picker.shiftEndTime(by: -60)
        #expect(picker.isInvalid)
        #expect(!picker.canApply)
        #expect(picker.durationLabel == "")

        picker.apply()
        #expect(applied.isEmpty)
    }

    @Test func periodLabels() {
        let picker = picker()
        picker.tab = .period
        #expect(picker.startDayLabel == "Сегодня, 8 нояб.")
        #expect(picker.startTimeLabel == "10:00")
        #expect(picker.endTimeLabel == "11:00")
        #expect(picker.durationLabel == "1 ч")

        picker.shiftStartDay(by: 4)
        #expect(picker.startDayLabel == "Чт, 12 нояб.")
    }

    // MARK: - Колёса точного времени

    @Test func openWheelPositionsOnStart() {
        let picker = picker()
        picker.openWheel(.start)
        #expect(picker.isWheelOpen)
        #expect(picker.wheelEdge == .start)
        #expect(picker.wheelDayIndex == 90)
        #expect(picker.wheelHour == 10)
        #expect(picker.wheelMinute == 0)
        #expect(picker.wheelDayLabel(90) == "Сегодня")
        #expect(picker.wheelDayLabel(91).hasPrefix("Пн"))
        #expect(picker.wheelSummary == "1 ч")
        #expect(DateTimePickerViewModel.wheelDayCount == 181)
    }

    @Test func movingStartMovesEndWithSameDuration() {
        let picker = picker()
        picker.openWheel(.start)
        picker.wheelHour = 11
        picker.wheelMinute = 30
        #expect(picker.wheel?.startMinute == 690)
        #expect(picker.wheel?.endMinute == 750)
        #expect(picker.wheelSummary == "1 ч")
    }

    @Test func movingStartPastMidnightCarriesEndToNextDay() {
        let picker = picker()
        picker.openWheel(.start)
        picker.wheelHour = 23
        #expect(picker.wheel?.endDay == date("2026-11-09"))
        #expect(picker.wheel?.endMinute == 0)
        #expect(picker.wheelSummary == "1 ч · 2 дн.")
    }

    @Test func movingStartDayMovesEndDay() {
        let picker = picker()
        picker.openWheel(.start)
        picker.wheelDayIndex = 93
        #expect(picker.wheel?.startDay == date("2026-11-11"))
        #expect(picker.wheel?.endDay == date("2026-11-11"))
    }

    @Test func endEdgeChangesDurationAndCanBeInvalid() {
        let picker = picker()
        picker.openWheel(.start)
        picker.wheelEdge = .end
        #expect(picker.wheelHour == 11)

        picker.wheelMinute = 45
        #expect(picker.wheel?.endMinute == 705)
        #expect(picker.wheelSummary == "1 ч 45 мин")

        picker.wheelHour = 9
        #expect(picker.isWheelInvalid)
        #expect(picker.wheelSummary == "Конец раньше начала")
    }

    @Test func applyWheelUpdatesSelection() {
        let picker = picker(selection(hasTime: false))
        picker.openWheel(.start)
        picker.wheelDayIndex = 92
        picker.wheelHour = 14
        picker.applyWheel()

        #expect(!picker.isWheelOpen)
        #expect(picker.selection.day == date("2026-11-10"))
        #expect(picker.selection.startMinute == 840)
        #expect(picker.selection.endMinute == 900)
        #expect(picker.selection.hasTime)
        #expect(picker.monthTitle == "Ноябрь")
    }

    @Test func cancelWheelKeepsSelectionAndIgnoresLaterEdits() {
        let picker = picker()
        picker.openWheel(.start)
        picker.wheelHour = 15
        picker.cancelWheel()
        #expect(!picker.isWheelOpen)
        #expect(picker.selection.startMinute == 600)

        // Черновик остаётся, но после закрытия не меняется и не применяется.
        picker.wheelHour = 20
        #expect(picker.wheel?.startMinute == 900)
        picker.applyWheel()
        #expect(picker.selection.startMinute == 600)
    }

    @Test func wheelEndCannotBeMidnightOfNextDay() {
        let picker = picker(selection(start: 1380, end: 1440))
        picker.openWheel(.end)
        #expect(picker.wheel?.endMinute == 1439)
    }

    // MARK: - Напоминание и повтор

    @Test func reminderAndRepeatOptions() {
        let picker = picker(selection(reminder: .tenMinutesBefore))
        #expect(picker.hasReminder)
        #expect(!picker.hasRepeat)
        #expect(picker.reminderOptions.filter(\.isSelected).map(\.value) == [.tenMinutesBefore])
        #expect(picker.reminderTitle == ReminderOption.tenMinutesBefore.title)

        picker.setRepeat(.weekly)
        picker.setReminder(.none)
        #expect(picker.hasRepeat)
        #expect(!picker.hasReminder)
        #expect(picker.repeatOptions.filter(\.isSelected).map(\.value) == [.weekly])
        #expect(picker.repeatTitle == "Каждую неделю")
    }

    @Test func onlyOneSectionIsExpanded() {
        let picker = picker()
        picker.toggleReminder()
        #expect(picker.isReminderExpanded)
        picker.toggleRepeat()
        #expect(picker.isRepeatExpanded)
        #expect(!picker.isReminderExpanded)
        picker.toggleRepeat()
        #expect(!picker.isRepeatExpanded)
    }

    // MARK: - Пересечение

    @Test func conflictWithOtherTask() {
        let lunch = fixture.task("Обед", due: "2026-11-08 10:30")
        #expect(picker(tasks: [lunch]).conflictText == "Пересекается с «Обед» (10:30 – 11:30). Всё равно можно добавить.")
        #expect(picker(tasks: [lunch], excluding: lunch.id).conflictText == nil)
        #expect(picker(selection(hasTime: false), tasks: [lunch]).conflictText == nil)
        #expect(picker(selection(start: 690, end: 750), tasks: [lunch]).conflictText == nil)
    }

    // MARK: - Готово

    @Test func applyOnDateTabMakesSingleDayWithKeptDuration() throws {
        let picker = picker(selection(start: 600, end: 690))
        picker.select(day: date("2026-11-09"))
        picker.shiftStartTime(by: 60)
        picker.apply()

        let result = try #require(applied.first)
        #expect(result.day == date("2026-11-09"))
        #expect(result.endDay == date("2026-11-09"))
        #expect(result.startMinute == 660)
        #expect(result.endMinute == 750)
        #expect(!result.isPeriod)
    }

    @Test func applyOnPeriodTabMarksPeriod() throws {
        let picker = picker()
        picker.tab = .period
        picker.shiftEndDay(by: 1)
        picker.apply()

        let result = try #require(applied.first)
        #expect(result.isPeriod)
        #expect(result.hasTime)
        #expect(result.endDay == date("2026-11-09"))
    }

    @Test func applyWithoutDate() throws {
        let picker = picker()
        picker.selectPreset("none")
        picker.apply()
        let result = try #require(applied.first)
        #expect(result.day == nil)
        #expect(!result.isPeriod)
    }
}
