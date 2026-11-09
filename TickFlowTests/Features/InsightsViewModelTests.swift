import Foundation
import Testing
@testable import TickFlow

/// Сегодня — воскресенье 08.11.2026. Неделя: 02–08.11, прошлая: 26.10–01.11.
@MainActor
struct InsightsViewModelTests {
    let fixture: ModelFixture
    let clock = FixedClock("2026-11-08 09:00")
    let tasks = FakeTaskRepository()
    let habits = FakeHabitRepository()
    let settings = FakeSettingsRepository()

    init() throws {
        fixture = try ModelFixture()
    }

    private func screen(_ range: InsightsViewModel.Range = .week) -> InsightsViewModel {
        let screen = InsightsViewModel(tasks: tasks, habits: habits, settings: settings, navigator: AppNavigator(), clock: clock)
        screen.range = range
        return screen
    }

    @discardableResult
    private func task(_ title: String, created: String, due: String? = nil, completed: String? = nil) -> TaskItem {
        let item = fixture.task(title, due: due)
        item.createdAt = date(created)
        if let completed {
            item.isCompleted = true
            item.completedAt = date(completed)
        }
        tasks.insert([item])
        return item
    }

    /// Две выполненные задачи в эту неделю, одна просроченная, одна выполненная — в прошлую.
    private func seedWeek() {
        task("A", created: "2026-11-03 08:00", due: "2026-11-03 10:00", completed: "2026-11-03 10:30")
        task("B", created: "2026-11-04 08:00", due: "2026-11-04 11:00", completed: "2026-11-04 11:20")
        task("C", created: "2026-11-04 09:00", due: "2026-11-05")
        task("D", created: "2026-10-28 08:00", due: "2026-10-28", completed: "2026-10-28 18:00")
    }

    @Test func emptyState() {
        let screen = screen()
        #expect(!screen.hasData)
        #expect(!screen.hasHabits)
        let report = screen.report
        #expect(report.kpis.allSatisfy { $0.isNeutral })
        #expect(report.kpis.map(\.delta).first == "Как в прошлом периоде")
        #expect(report.kpis[2].delta == "Нет данных для сравнения")
        #expect(report.note == "Пока мало данных. Отмечайте задачи выполненными — здесь появятся выводы.")
        #expect(report.consistency == "—")
        #expect(report.habits.isEmpty)
        #expect(report.facts.map(\.title) == ["Самый продуктивный день", "Пиковые часы", "В среднем за день"])
        #expect(report.facts.map(\.value) == ["—", "—", "0"])
        #expect(report.maxBarValue == 1)
    }

    @Test func weekKpisAgainstPreviousWeek() {
        seedWeek()
        let report = screen().report
        #expect(report.period == "Последние 7 дней")
        #expect(report.kpis.map(\.title) == ["Выполнено", "Создано", "Выполнение", "Просрочено"])
        #expect(report.kpis.map(\.value) == ["2", "3", "67%", "1"])
        #expect(report.kpis.map(\.delta) == [
            "+100% к прошлому периоду", "+200% к прошлому периоду", "-33 п.п. к прошлому", "+1 к прошлому периоду",
        ])
        #expect(report.kpis.map(\.isGood) == [true, true, false, false])
        #expect(report.kpis.allSatisfy { !$0.isNeutral })
    }

    @Test func firstCompletionsHaveNoComparison() {
        task("A", created: "2026-11-03", due: "2026-11-03", completed: "2026-11-03 12:00")
        let kpis = screen().report.kpis
        #expect(kpis[0].delta == "Нет данных для сравнения")
        #expect(kpis[0].isNeutral)
        #expect(kpis[2].delta == "Нет данных для сравнения")
        #expect(kpis[2].isGood)
    }

    @Test func fewerCompletionsIsBad() {
        task("A", created: "2026-10-27", completed: "2026-10-27 12:00")
        task("B", created: "2026-10-28", completed: "2026-10-28 12:00")
        task("C", created: "2026-11-03", completed: "2026-11-03 12:00")
        let completed = screen().report.kpis[0]
        #expect(completed.delta == "-50% к прошлому периоду")
        #expect(!completed.isGood)
    }

    /// Сегодняшняя невыполненная задача не портит процент: день ещё не закончился.
    @Test func todayOpenTaskIsNotCountedInRate() {
        task("A", created: "2026-11-07", due: "2026-11-07", completed: "2026-11-07 12:00")
        task("B", created: "2026-11-07", due: "2026-11-08")
        #expect(screen().report.kpis[2].value == "100%")
    }

    @Test func weekBarsAndNote() {
        seedWeek()
        let report = screen().report
        #expect(report.chartTitle == "По дням")
        #expect(report.bars.map(\.label) == ["П", "В", "С", "Ч", "П", "С", "В"])
        #expect(report.bars.map(\.created) == [0, 1, 2, 0, 0, 0, 0])
        #expect(report.bars.map(\.completed) == [0, 1, 1, 0, 0, 0, 0])
        // При равенстве лучший — первый столбец.
        #expect(report.bars.map(\.isBest) == [false, true, false, false, false, false, false])
        #expect(report.maxBarValue == 2)
        #expect(report.note == "Самый продуктивный день — вторник: 1 задача. Чаще всего задачи выполняются в 10:00–12:00.")
        #expect(report.facts.map(\.value) == ["Вторник", "10:00–12:00", "0,3"])
    }

    @Test func peakHoursUseTwelveHourClock() {
        settings.settings.uses24HourTime = false
        seedWeek()
        #expect(screen().report.facts[1].value == "10:00–12:00")

        task("E", created: "2026-11-05", due: "2026-11-05 14:00", completed: "2026-11-05 15:00")
        task("F", created: "2026-11-05", due: "2026-11-05 14:00", completed: "2026-11-05 16:00")
        task("G", created: "2026-11-05", due: "2026-11-05 14:00", completed: "2026-11-05 16:30")
        #expect(screen().report.facts[1].value == "3:00–5:00")
    }

    @Test func monthRange() {
        task("A", created: "2026-11-01", completed: "2026-11-01 12:00")
        task("B", created: "2026-11-02", completed: "2026-11-02 12:00")
        task("C", created: "2026-10-12", completed: "2026-10-12 12:00")
        let report = screen(.month).report

        #expect(report.period == "Последние 30 дней")
        #expect(report.chartTitle == "По неделям")
        // 10.10–08.11: четыре недели, хвост 07–08.11 присоединён к последней.
        #expect(report.bars.map(\.label) == ["10 окт.", "17 окт.", "24 окт.", "31 окт."])
        #expect(report.bars.map(\.completed) == [1, 0, 0, 2])
        #expect(report.note == "Лучшая неделя — с 31 окт.: 2 задачи.")
    }

    @Test func yearRange() {
        task("A", created: "2026-03-05", completed: "2026-03-05 12:00")
        let report = screen(.year).report
        #expect(report.period == "Последние 12 месяцев")
        #expect(report.chartTitle == "По месяцам")
        #expect(report.bars.count == 12)
        #expect(report.bars.first?.title == "декабрь")
        #expect(report.bars.last?.title == "ноябрь")
        #expect(report.note == "Лучший месяц — март: 1 задача.")
    }

    @Test func rangeOptions() {
        #expect(screen().rangeOptions.map(\.title) == ["Неделя", "Месяц", "Год"])
    }

    @Test func habitRowsAndConsistency() {
        let reading = fixture.habit("Чтение")
        fixture.done(reading, "2026-11-06", "2026-11-07", "2026-11-08")
        let water = fixture.habit("Вода", start: "2026-10-20")
        fixture.done(water, "2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05", "2026-11-06", "2026-11-07", "2026-11-08")
        fixture.done(water, "2026-10-26")
        habits.insert([reading, water])
        let screen = screen()
        let report = screen.report

        #expect(screen.hasData)
        #expect(screen.hasHabits)
        #expect(report.habits.map(\.name) == ["Вода", "Чтение"])
        #expect(report.habits.map(\.detail) == ["100% · серия 7 дней", "43% · серия 3 дня"])
        #expect(report.consistency == "71%")
        // Прошлая неделя: вода 1/7, чтение 0/1 (началось 01.11) → среднее 7%.
        #expect(report.facts.first?.title == "Привычки, прошлый период")
        #expect(report.facts.first?.value == "7%")
    }
}
