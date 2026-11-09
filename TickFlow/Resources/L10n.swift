// Сгенерировано из списка строк приложения. Значения по умолчанию — русские (исходный язык),
// переводы лежат в Localizable.xcstrings.

import Foundation

/// Все тексты интерфейса. Строка ищется в Localizable.xcstrings по ключу,
/// русский вариант — запасной, если перевода нет.
enum L10n {
    enum Common {
        static var cancel: String { String(localized: "common.cancel", defaultValue: "Отмена") }
        static var undo: String { String(localized: "common.undo", defaultValue: "Отменить") }
        static var done: String { String(localized: "common.done", defaultValue: "Готово") }
        static var save: String { String(localized: "common.save", defaultValue: "Сохранить") }
        static var saved: String { String(localized: "common.saved", defaultValue: "Сохранено") }
        static var add: String { String(localized: "common.add", defaultValue: "Добавить") }
        static var delete: String { String(localized: "common.delete", defaultValue: "Удалить") }
        static var edit: String { String(localized: "common.edit", defaultValue: "Изменить") }
        static var `open`: String { String(localized: "common.open", defaultValue: "Открыть") }
        static var close: String { String(localized: "common.close", defaultValue: "Закрыть") }
        static var apply: String { String(localized: "common.apply", defaultValue: "Применить") }
        static var reset: String { String(localized: "common.reset", defaultValue: "Сбросить") }
        static var back: String { String(localized: "common.back", defaultValue: "Назад") }
        static var more: String { String(localized: "common.more", defaultValue: "Ещё") }
        static var show: String { String(localized: "common.show", defaultValue: "Показать") }
        static var hide: String { String(localized: "common.hide", defaultValue: "Скрыть") }
        static var all: String { String(localized: "common.all", defaultValue: "Все") }
        static var none: String { String(localized: "common.none", defaultValue: "Нет") }
        static var search: String { String(localized: "common.search", defaultValue: "Поиск") }
        static var filter: String { String(localized: "common.filter", defaultValue: "Фильтр") }
        static var today: String { String(localized: "common.today", defaultValue: "Сегодня") }
        static var tomorrow: String { String(localized: "common.tomorrow", defaultValue: "Завтра") }
        static var yesterday: String { String(localized: "common.yesterday", defaultValue: "Вчера") }
        static var noDate: String { String(localized: "common.noDate", defaultValue: "Без даты") }
        static var noCategory: String { String(localized: "common.noCategory", defaultValue: "Без категории") }
        static var date: String { String(localized: "common.date", defaultValue: "Дата") }
        static var time: String { String(localized: "common.time", defaultValue: "Время") }
        static var priority: String { String(localized: "common.priority", defaultValue: "Приоритет") }
        static var category: String { String(localized: "common.category", defaultValue: "Категория") }
        static var categories: String { String(localized: "common.categories", defaultValue: "Категории") }
        static var reminder: String { String(localized: "common.reminder", defaultValue: "Напоминание") }
        static var `repeat`: String { String(localized: "common.repeat", defaultValue: "Повтор") }
        static var start: String { String(localized: "common.start", defaultValue: "Начало") }
        static var end: String { String(localized: "common.end", defaultValue: "Конец") }
        static var period: String { String(localized: "common.period", defaultValue: "Период") }
        static var status: String { String(localized: "common.status", defaultValue: "Статус") }
        static var completed: String { String(localized: "common.completed", defaultValue: "Выполнено") }
        static var created: String { String(localized: "common.created", defaultValue: "Создано") }
        static var overdue: String { String(localized: "common.overdue", defaultValue: "Просрочено") }
        static var planned: String { String(localized: "common.planned", defaultValue: "Запланировано") }
        static var skipped: String { String(localized: "common.skipped", defaultValue: "Пропущено") }
        static var notDone: String { String(localized: "common.notDone", defaultValue: "Не выполнено") }
        static var restDay: String { String(localized: "common.restDay", defaultValue: "День отдыха") }
        static var restDays: String { String(localized: "common.restDays", defaultValue: "Дни отдыха") }
        static var markDone: String { String(localized: "common.markDone", defaultValue: "Отметить выполненной") }
        static var markUndone: String { String(localized: "common.markUndone", defaultValue: "Отметить невыполненной") }
        static var unmark: String { String(localized: "common.unmark", defaultValue: "Снять отметку") }
        static var mark: String { String(localized: "common.mark", defaultValue: "Отметить") }
        static var overlap: String { String(localized: "common.overlap", defaultValue: "Пересечение") }
        static var timeConflict: String { String(localized: "common.timeConflict", defaultValue: "Пересечение по времени") }
        static var recurringTask: String { String(localized: "common.recurringTask", defaultValue: "Повторяющаяся задача") }
        static var thisOccurrence: String { String(localized: "common.thisOccurrence", defaultValue: "Только это вхождение") }
        static var thisAndFollowing: String { String(localized: "common.thisAndFollowing", defaultValue: "Это и следующие") }
        static var thisOccurrenceSuffix: String { String(localized: "common.thisOccurrenceSuffix", defaultValue: " (только это вхождение)") }
        static var keepBothMasculine: String { String(localized: "common.keepBothMasculine", defaultValue: "Оставить оба") }
        static var keepBoth: String { String(localized: "common.keepBoth", defaultValue: "Оставить обе") }
        static var allDay: String { String(localized: "common.allDay", defaultValue: "Весь день") }
        static var allDayShort: String { String(localized: "common.allDayShort", defaultValue: "весь\nдень") }
        static var allDayShortCapitalized: String { String(localized: "common.allDayShortCapitalized", defaultValue: "Весь\nдень") }
        static var newTask: String { String(localized: "common.newTask", defaultValue: "Новая задача") }
        static var addTask: String { String(localized: "common.addTask", defaultValue: "Добавить задачу") }
        static var loadSample: String { String(localized: "common.loadSample", defaultValue: "Загрузить пример") }
        static var loadSampleData: String { String(localized: "common.loadSampleData", defaultValue: "Загрузить пример данных") }
        static var streak: String { String(localized: "common.streak", defaultValue: "серия") }
        static var everyDay: String { String(localized: "common.everyDay", defaultValue: "Каждый день") }
        static var weekdays: String { String(localized: "common.weekdays", defaultValue: "По будням") }
        static var copySuffix: String { String(localized: "common.copySuffix", defaultValue: " (копия)") }
        static var mondayShort: String { String(localized: "common.mondayShort", defaultValue: "Пн") }
        static var monday: String { String(localized: "common.monday", defaultValue: "Понедельник") }
        static var sunday: String { String(localized: "common.sunday", defaultValue: "Воскресенье") }
        static var dash: String { String(localized: "common.dash", defaultValue: "—") }
        static var overlapsShort: String { String(localized: "common.overlapsShort", defaultValue: " · Пересекается") }
        static var todaySuffix: String { String(localized: "common.todaySuffix", defaultValue: " · Сегодня") }
        static func doneOfTotal(_ done: Int, _ total: Int) -> String {
            String(localized: "common.doneOfTotal", defaultValue: "\(done) из \(total) выполнено")
        }
        static func ofTotal(_ done: Int, _ total: Int) -> String {
            String(localized: "common.ofTotal", defaultValue: "\(done) из \(total)")
        }
        static func deleteNamed(_ name: String) -> String {
            String(localized: "common.deleteNamed", defaultValue: "Удалить «\(name)»?")
        }
        static func overlapMessage(_ title: String, _ other: String, _ start: String, _ end: String) -> String {
            String(localized: "common.overlapMessage", defaultValue: "«\(title)» пересекается с «\(other)» (\(start) – \(end)).")
        }
    }

    enum Tab {
        static var tasks: String { String(localized: "tab.tasks", defaultValue: "Задачи") }
        static var calendar: String { String(localized: "tab.calendar", defaultValue: "Календарь") }
        static var habits: String { String(localized: "tab.habits", defaultValue: "Привычки") }
        static var profile: String { String(localized: "tab.profile", defaultValue: "Профиль") }
    }

    enum Format {
        static func minutes(_ minutes: Int) -> String {
            String(localized: "format.minutes", defaultValue: "\(minutes) мин")
        }
        static func hours(_ hours: Int) -> String {
            String(localized: "format.hours", defaultValue: "\(hours) ч")
        }
        static func hoursMinutes(_ hours: Int, _ minutes: Int) -> String {
            String(localized: "format.hoursMinutes", defaultValue: "\(hours) ч \(minutes) мин")
        }
        static func daysShort(_ days: Int) -> String {
            String(localized: "format.daysShort", defaultValue: "\(days) дн.")
        }
        static func weeksShort(_ weeks: Int) -> String {
            String(localized: "format.weeksShort", defaultValue: "\(weeks) нед.")
        }
        static var minutesUnit: String { String(localized: "format.minutesUnit", defaultValue: "мин") }
    }

    enum Plural {
        static func days(_ count: Int) -> String {
            String(localized: "plural.days", defaultValue: "\(count) дней")
        }
        static func tasks(_ count: Int) -> String {
            String(localized: "plural.tasks", defaultValue: "\(count) задач")
        }
        static func times(_ count: Int) -> String {
            String(localized: "plural.times", defaultValue: "\(count) раз")
        }
        static func habitsOf(_ count: Int) -> String {
            String(localized: "plural.habitsOf", defaultValue: "\(count) привычек")
        }
        static func habitsToAdd(_ count: Int) -> String {
            String(localized: "plural.habitsToAdd", defaultValue: "\(count) привычек")
        }
    }

    enum Tasks {
        static var searchPlaceholder: String { String(localized: "tasks.searchPlaceholder", defaultValue: "Поиск задач") }
        static var clearSearch: String { String(localized: "tasks.clearSearch", defaultValue: "Очистить поиск") }
        static var noResultsMessage: String { String(localized: "tasks.noResultsMessage", defaultValue: "Проверьте написание или попробуйте другое слово.") }
        static var emptyTitle: String { String(localized: "tasks.emptyTitle", defaultValue: "Пока нет задач") }
        static var emptyMessage: String { String(localized: "tasks.emptyMessage", defaultValue: "Запишите, что на уме. Дата и время необязательны.") }
        static var sortLabel: String { String(localized: "tasks.sortLabel", defaultValue: "Сортировка:") }
        static var upcoming: String { String(localized: "tasks.upcoming", defaultValue: "Предстоящие") }
        static var comfortableView: String { String(localized: "tasks.comfortableView", defaultValue: "Обычный вид") }
        static var compactView: String { String(localized: "tasks.compactView", defaultValue: "Компактный вид") }
        static var deleted: String { String(localized: "tasks.deleted", defaultValue: "Задача удалена") }
        static func noResultsTitle(_ query: String) -> String {
            String(localized: "tasks.noResultsTitle", defaultValue: "Ничего не найдено по «\(query)»")
        }
        static func completedToast(_ title: String) -> String {
            String(localized: "tasks.completedToast", defaultValue: "Выполнено «\(title)»")
        }
    }

    enum Calendar {
        static var view: String { String(localized: "calendar.view", defaultValue: "Вид") }
        static var viewMenu: String { String(localized: "calendar.viewMenu", defaultValue: "Вид календаря") }
        static var day: String { String(localized: "calendar.day", defaultValue: "День") }
        static var threeDays: String { String(localized: "calendar.threeDays", defaultValue: "3 дня") }
        static var week: String { String(localized: "calendar.week", defaultValue: "Неделя") }
        static var month: String { String(localized: "calendar.month", defaultValue: "Месяц") }
        static var markIncomplete: String { String(localized: "calendar.markIncomplete", defaultValue: "Вернуть в работу") }
        static var emptyTitle: String { String(localized: "calendar.emptyTitle", defaultValue: "Календарь пуст") }
        static var emptyMessage: String { String(localized: "calendar.emptyMessage", defaultValue: "Добавьте задачу или привычку — или загрузите пример, чтобы посмотреть, как всё работает.") }
        static var createFirstTask: String { String(localized: "calendar.createFirstTask", defaultValue: "Создать первую задачу") }
        static var addFirstHabit: String { String(localized: "calendar.addFirstHabit", defaultValue: "Добавить первую привычку") }
        static var nothingScheduled: String { String(localized: "calendar.nothingScheduled", defaultValue: "Ничего не запланировано") }
        static var tapTimeToAdd: String { String(localized: "calendar.tapTimeToAdd", defaultValue: "Нажмите на время, чтобы добавить задачу.") }
        static func movedTo(_ when: String) -> String {
            String(localized: "calendar.movedTo", defaultValue: "Перенесено на \(when)")
        }
        static func nowRange(_ range: String) -> String {
            String(localized: "calendar.nowRange", defaultValue: "Теперь \(range)")
        }
        static func dayOfTotal(_ index: Int, _ total: Int) -> String {
            String(localized: "calendar.dayOfTotal", defaultValue: "День \(index) из \(total)")
        }
        static var trackedLegend: String { String(localized: "calendar.trackedLegend", defaultValue: "Учтено") }
        static var trackedTime: String { String(localized: "calendar.trackedTime", defaultValue: "Учтённое время") }
        static var sessionStopped: String { String(localized: "calendar.sessionStopped", defaultValue: "остановлена") }
        static var sessionNow: String { String(localized: "calendar.sessionNow", defaultValue: "сейчас") }
        static var inProgress: String { String(localized: "calendar.inProgress", defaultValue: "Идёт") }
        static func trackedTotal(_ duration: String, _ sessions: String) -> String {
            String(localized: "calendar.trackedTotal", defaultValue: "\(duration) · \(sessions)")
        }
    }

    enum Editor {
        static var titlePlaceholder: String { String(localized: "editor.titlePlaceholder", defaultValue: "Что нужно сделать?") }
        static var notesPlaceholder: String { String(localized: "editor.notesPlaceholder", defaultValue: "Описание") }
        static var openFullScreen: String { String(localized: "editor.openFullScreen", defaultValue: "Открыть во весь экран") }
        static var duplicate: String { String(localized: "editor.duplicate", defaultValue: "Дублировать") }
        static var discardDraft: String { String(localized: "editor.discardDraft", defaultValue: "Удалить черновик") }
        static var subtasksHeader: String { String(localized: "editor.subtasksHeader", defaultValue: "ПОДЗАДАЧИ") }
        static var deleteSubtask: String { String(localized: "editor.deleteSubtask", defaultValue: "Удалить подзадачу") }
        static var addSubtask: String { String(localized: "editor.addSubtask", defaultValue: "Добавить подзадачу") }
        static var hideKeyboard: String { String(localized: "editor.hideKeyboard", defaultValue: "Скрыть клавиатуру") }
        static var dateAndReminder: String { String(localized: "editor.dateAndReminder", defaultValue: "Дата и напоминание") }
        static var deleteTaskQuestion: String { String(localized: "editor.deleteTaskQuestion", defaultValue: "Удалить задачу?") }
        static var deleteTask: String { String(localized: "editor.deleteTask", defaultValue: "Удалить задачу") }
        static var deleteTaskMessage: String { String(localized: "editor.deleteTaskMessage", defaultValue: "Задача и её подзадачи будут удалены. Сразу после этого можно отменить.") }
        static var copyCreated: String { String(localized: "editor.copyCreated", defaultValue: "Создана копия") }
        static var changesSaved: String { String(localized: "editor.changesSaved", defaultValue: "Изменения сохранены") }
        static var changesSavedThisOccurrence: String { String(localized: "editor.changesSavedThisOccurrence", defaultValue: "Изменения сохранены (только это вхождение)") }
        static func addedToast(_ when: String) -> String {
            String(localized: "editor.addedToast", defaultValue: "Добавлено · \(when)")
        }
        static func overlapsWith(_ title: String) -> String {
            String(localized: "editor.overlapsWith", defaultValue: "Пересекается с «\(title)»")
        }
    }

    enum DatePicker {
        static var noDateHint: String { String(localized: "datePicker.noDateHint", defaultValue: "Без даты задача попадёт в раздел «Без даты».") }
        static var endBeforeStart: String { String(localized: "datePicker.endBeforeStart", defaultValue: "Конец раньше начала.") }
        static var endBeforeStartShort: String { String(localized: "datePicker.endBeforeStartShort", defaultValue: "Конец раньше начала") }
        static var removeTime: String { String(localized: "datePicker.removeTime", defaultValue: "Убрать время") }
        static var openExactTime: String { String(localized: "datePicker.openExactTime", defaultValue: "Открыть точный выбор времени") }
        static var nextMonday: String { String(localized: "datePicker.nextMonday", defaultValue: "След. понедельник") }
        static func conflict(_ title: String, _ start: String, _ end: String) -> String {
            String(localized: "datePicker.conflict", defaultValue: "Пересекается с «\(title)» (\(start) – \(end)). Всё равно можно добавить.")
        }
    }

    enum Lists {
        static var newCategory: String { String(localized: "lists.newCategory", defaultValue: "Новая категория") }
        static var namePlaceholder: String { String(localized: "lists.namePlaceholder", defaultValue: "Название категории") }
        static var color: String { String(localized: "lists.color", defaultValue: "Цвет") }
        static var icon: String { String(localized: "lists.icon", defaultValue: "Иконка") }
        static var deleteCategory: String { String(localized: "lists.deleteCategory", defaultValue: "Удалить категорию") }
        static var noTasks: String { String(localized: "lists.noTasks", defaultValue: "В категории нет задач.") }
        static func deleteWarning(_ tasks: String) -> String {
            String(localized: "lists.deleteWarning", defaultValue: "Вместе с категорией удалятся \(tasks). Это нельзя отменить.")
        }
        static func deletedToast(_ name: String) -> String {
            String(localized: "lists.deletedToast", defaultValue: "Категория «\(name)» удалена")
        }
        static var trackByDefault: String { String(localized: "lists.trackByDefault", defaultValue: "Учёт времени по умолчанию") }
        static var trackingOnFootnote: String { String(localized: "lists.trackingOnFootnote", defaultValue: "Задачи категории показывают таймер, «Начать фокус» и потраченное время против оценки.") }
        static var trackingOffFootnote: String { String(localized: "lists.trackingOffFootnote", defaultValue: "Задачи категории не показывают учёт времени. Любую задачу можно настроить отдельно в её меню ⋯.") }
        static func overrides(_ count: Int) -> String {
            String(localized: "lists.overrides", defaultValue: "\(count) задачи настроены иначе.")
        }
        static func createdToast(_ name: String) -> String {
            String(localized: "lists.createdToast", defaultValue: "Категория «\(name)» создана")
        }
        static var newCategoryEllipsis: String { String(localized: "lists.newCategoryEllipsis", defaultValue: "Новая категория…") }
        static var trackingBadge: String { String(localized: "lists.trackingBadge", defaultValue: "Учёт") }
        static var screenFootnote: String { String(localized: "lists.screenFootnote", defaultValue: "Нажмите на категорию, чтобы изменить её и включить или выключить учёт времени для её задач. Любую задачу можно настроить отдельно в её меню ⋯.") }
        static func openTasks(_ count: Int) -> String {
            String(localized: "lists.openTasks", defaultValue: "\(count) открытой задачи")
        }
    }

    enum Insights {
        static var title: String { String(localized: "insights.title", defaultValue: "Аналитика") }
        static var emptyTitle: String { String(localized: "insights.emptyTitle", defaultValue: "Пока нет данных") }
        static var emptyMessage: String { String(localized: "insights.emptyMessage", defaultValue: "Добавляйте и выполняйте задачи и привычки — здесь появится статистика.") }
        static var habitConsistency: String { String(localized: "insights.habitConsistency", defaultValue: "Регулярность привычек") }
        static var noComparison: String { String(localized: "insights.noComparison", defaultValue: "Нет данных для сравнения") }
        static var sameAsPrevious: String { String(localized: "insights.sameAsPrevious", defaultValue: "Как в прошлом периоде") }
        static var year: String { String(localized: "insights.year", defaultValue: "Год") }
        static var completionRate: String { String(localized: "insights.completionRate", defaultValue: "Выполнение") }
        static var mostProductiveDay: String { String(localized: "insights.mostProductiveDay", defaultValue: "Самый продуктивный день") }
        static var peakHours: String { String(localized: "insights.peakHours", defaultValue: "Пиковые часы") }
        static var dailyAverage: String { String(localized: "insights.dailyAverage", defaultValue: "В среднем за день") }
        static var habitsPreviousPeriod: String { String(localized: "insights.habitsPreviousPeriod", defaultValue: "Привычки, прошлый период") }
        static var last7Days: String { String(localized: "insights.last7Days", defaultValue: "Последние 7 дней") }
        static var last30Days: String { String(localized: "insights.last30Days", defaultValue: "Последние 30 дней") }
        static var last12Months: String { String(localized: "insights.last12Months", defaultValue: "Последние 12 месяцев") }
        static var byDay: String { String(localized: "insights.byDay", defaultValue: "По дням") }
        static var byWeek: String { String(localized: "insights.byWeek", defaultValue: "По неделям") }
        static var byMonth: String { String(localized: "insights.byMonth", defaultValue: "По месяцам") }
        static var notEnoughData: String { String(localized: "insights.notEnoughData", defaultValue: "Пока мало данных. Отмечайте задачи выполненными — здесь появятся выводы.") }
        static func periodCaption(_ period: String) -> String {
            String(localized: "insights.periodCaption", defaultValue: "\(period) · по сравнению с прошлым периодом")
        }
        static func habitDetail(_ rate: String, _ streak: String) -> String {
            String(localized: "insights.habitDetail", defaultValue: "\(rate) · серия \(streak)")
        }
        static func noteBestWeekday(_ weekday: String, _ tasks: String) -> String {
            String(localized: "insights.noteBestWeekday", defaultValue: "Самый продуктивный день — \(weekday): \(tasks).")
        }
        static func noteBestWeek(_ start: String, _ tasks: String) -> String {
            String(localized: "insights.noteBestWeek", defaultValue: "Лучшая неделя — с \(start): \(tasks).")
        }
        static func noteBestMonth(_ month: String, _ tasks: String) -> String {
            String(localized: "insights.noteBestMonth", defaultValue: "Лучший месяц — \(month): \(tasks).")
        }
        static func notePeak(_ hours: String) -> String {
            String(localized: "insights.notePeak", defaultValue: "Чаще всего задачи выполняются в \(hours).")
        }
        static func deltaCount(_ count: Int) -> String {
            String(localized: "insights.deltaCount", defaultValue: "+\(count) к прошлому периоду")
        }
        static func deltaPercent(_ change: String) -> String {
            String(localized: "insights.deltaPercent", defaultValue: "\(change)% к прошлому периоду")
        }
        static func deltaPoints(_ change: String) -> String {
            String(localized: "insights.deltaPoints", defaultValue: "\(change) п.п. к прошлому")
        }
    }

    enum Habits {
        static var new: String { String(localized: "habits.new", defaultValue: "Новая привычка") }
        static var emptyTitle: String { String(localized: "habits.emptyTitle", defaultValue: "Начните с одной маленькой привычки") }
        static var emptyMessage: String { String(localized: "habits.emptyMessage", defaultValue: "Выберите подсказку или создайте свою. Цель можно поменять в любой момент.") }
        static var allDoneToday: String { String(localized: "habits.allDoneToday", defaultValue: "На сегодня всё выполнено") }
        static var markToStart: String { String(localized: "habits.markToStart", defaultValue: "Отмечайте привычки, чтобы начать серию") }
        static var skippedToday: String { String(localized: "habits.skippedToday", defaultValue: "Пропущено сегодня · серия сохранена") }
        static var restDayPrefix: String { String(localized: "habits.restDayPrefix", defaultValue: "День отдыха · ") }
        static var markCompletion: String { String(localized: "habits.markCompletion", defaultValue: "Отметить выполнение") }
        static func progress(_ done: Int, _ total: String) -> String {
            String(localized: "habits.progress", defaultValue: "\(done) из \(total) выполнено")
        }
        static func longestStreak(_ name: String, _ streak: String) -> String {
            String(localized: "habits.longestStreak", defaultValue: "Самая длинная серия: \(name), \(streak)")
        }
        static func doneToast(_ name: String, _ streak: String) -> String {
            String(localized: "habits.doneToast", defaultValue: "«\(name)» выполнено · серия \(streak)")
        }
        static func timesPerWeek(_ times: String) -> String {
            String(localized: "habits.timesPerWeek", defaultValue: "\(times) в неделю")
        }
        static func perDay(_ value: String, _ unit: String) -> String {
            String(localized: "habits.perDay", defaultValue: "\(value) \(unit) в день")
        }
        static func reminderBody(_ name: String) -> String {
            String(localized: "habits.reminderBody", defaultValue: "Время для привычки «\(name)»")
        }
        static var suggestionReading: String { String(localized: "habits.suggestionReading", defaultValue: "Чтение") }
        static var suggestionWater: String { String(localized: "habits.suggestionWater", defaultValue: "Пить воду") }
        static var suggestionWorkout: String { String(localized: "habits.suggestionWorkout", defaultValue: "Тренировка") }
        static var suggestionMeditation: String { String(localized: "habits.suggestionMeditation", defaultValue: "Медитация") }
        static var suggestionLearn: String { String(localized: "habits.suggestionLearn", defaultValue: "Узнать новое") }
        static var unitTimes: String { String(localized: "habits.unitTimes", defaultValue: "раз") }
        static var unitLiters: String { String(localized: "habits.unitLiters", defaultValue: "л") }
        static var unitPages: String { String(localized: "habits.unitPages", defaultValue: "стр.") }
        static var unitGlasses: String { String(localized: "habits.unitGlasses", defaultValue: "стак.") }
    }

    enum HabitDetail {
        static var weeklyTrend: String { String(localized: "habitDetail.weeklyTrend", defaultValue: "Тренд по неделям") }
        static var eightWeeks: String { String(localized: "habitDetail.eightWeeks", defaultValue: "8 недель") }
        static var currentStreak: String { String(localized: "habitDetail.currentStreak", defaultValue: "Текущая серия") }
        static var personalBest: String { String(localized: "habitDetail.personalBest", defaultValue: "Личный рекорд") }
        static var bestStreak: String { String(localized: "habitDetail.bestStreak", defaultValue: "Лучшая серия") }
        static var allTime: String { String(localized: "habitDetail.allTime", defaultValue: "За всё время") }
        static var last4Weeks: String { String(localized: "habitDetail.last4Weeks", defaultValue: "За 4 недели") }
        static var last30Days: String { String(localized: "habitDetail.last30Days", defaultValue: "За 30 дней") }
        static var total: String { String(localized: "habitDetail.total", defaultValue: "Всего") }
        static var timesDone: String { String(localized: "habitDetail.timesDone", defaultValue: "Раз выполнено") }
        static var now: String { String(localized: "habitDetail.now", defaultValue: "Сейчас") }
        static var goal: String { String(localized: "habitDetail.goal", defaultValue: "Цель") }
        static var frequency: String { String(localized: "habitDetail.frequency", defaultValue: "Частота") }
        static var allowed: String { String(localized: "habitDetail.allowed", defaultValue: "Разрешены") }
        static var off: String { String(localized: "habitDetail.off", defaultValue: "Выкл.") }
        static var ruleWithSkips: String { String(localized: "habitDetail.ruleWithSkips", defaultValue: "Пропуски и дни отдыха не прерывают серию. Будущие дни не учитываются.") }
        static var ruleRestOnly: String { String(localized: "habitDetail.ruleRestOnly", defaultValue: "Дни отдыха не прерывают серию. Будущие дни не учитываются.") }
        static var markNotDone: String { String(localized: "habitDetail.markNotDone", defaultValue: "Отметить как невыполненное") }
        static var undoSkip: String { String(localized: "habitDetail.undoSkip", defaultValue: "Отменить пропуск") }
        static var skipToday: String { String(localized: "habitDetail.skipToday", defaultValue: "Пропустить сегодня") }
        static var unmarked: String { String(localized: "habitDetail.unmarked", defaultValue: "Отметка снята") }
        static var skippedStreakKept: String { String(localized: "habitDetail.skippedStreakKept", defaultValue: "Сегодня пропущено. Серия сохранена") }
        static var skippedToday: String { String(localized: "habitDetail.skippedToday", defaultValue: "Сегодня пропущено") }
        static func toRecord(_ streak: String) -> String {
            String(localized: "habitDetail.toRecord", defaultValue: "Ещё \(streak) до рекорда")
        }
        static func progress(_ value: String, _ target: String, _ unit: String) -> String {
            String(localized: "habitDetail.progress", defaultValue: "\(value) из \(target) \(unit)")
        }
        static func weeksAgo(_ weeks: Int) -> String {
            String(localized: "habitDetail.weeksAgo", defaultValue: "−\(weeks) н")
        }
    }

    enum HabitState {
        static var skipped: String { String(localized: "habitState.skipped", defaultValue: "Пропущено. Серия сохранена") }
        static var missed: String { String(localized: "habitState.missed", defaultValue: "Не выполнено. Ничего страшного, завтра новый день") }
        static var rest: String { String(localized: "habitState.rest", defaultValue: "День отдыха. Не запланировано") }
        static var today: String { String(localized: "habitState.today", defaultValue: "Запланировано на сегодня") }
        static var notStarted: String { String(localized: "habitState.notStarted", defaultValue: "До начала привычки") }
    }

    enum HabitEditor {
        static var edit: String { String(localized: "habitEditor.edit", defaultValue: "Изменить привычку") }
        static var delete: String { String(localized: "habitEditor.delete", defaultValue: "Удалить привычку") }
        static var deleteMessage: String { String(localized: "habitEditor.deleteMessage", defaultValue: "История отметок тоже будет удалена.") }
        static var suggestions: String { String(localized: "habitEditor.suggestions", defaultValue: "Подсказки") }
        static var namePlaceholder: String { String(localized: "habitEditor.namePlaceholder", defaultValue: "Название привычки") }
        static var tracking: String { String(localized: "habitEditor.tracking", defaultValue: "Отслеживание") }
        static var dailyGoal: String { String(localized: "habitEditor.dailyGoal", defaultValue: "Цель на день") }
        static var unit: String { String(localized: "habitEditor.unit", defaultValue: "Единица") }
        static var timesPerWeek: String { String(localized: "habitEditor.timesPerWeek", defaultValue: "Раз в неделю") }
        static var updated: String { String(localized: "habitEditor.updated", defaultValue: "Привычка обновлена") }
        static func addedToast(_ name: String) -> String {
            String(localized: "habitEditor.addedToast", defaultValue: "Привычка добавлена · \(name)")
        }
        static func deletedToast(_ name: String) -> String {
            String(localized: "habitEditor.deletedToast", defaultValue: "Привычка «\(name)» удалена")
        }
    }

    enum Search {
        static var placeholder: String { String(localized: "search.placeholder", defaultValue: "Поиск задач и дат") }
        static var suggestions: String { String(localized: "search.suggestions", defaultValue: "ПОДСКАЗКИ") }
        static var nothingFound: String { String(localized: "search.nothingFound", defaultValue: "Ничего не найдено") }
        static var suggestionReview: String { String(localized: "search.suggestionReview", defaultValue: "Ревью") }
        static func noMatches(_ query: String) -> String {
            String(localized: "search.noMatches", defaultValue: "Нет совпадений с «\(query)». Попробуйте слово покороче.")
        }
    }

    enum Filter {
        static var `open`: String { String(localized: "filter.open", defaultValue: "Открытые") }
        static var completed: String { String(localized: "filter.completed", defaultValue: "Выполненные") }
    }

    enum Profile {
        static var notificationsDenied: String { String(localized: "profile.notificationsDenied", defaultValue: "Уведомления выключены. Откройте Настройки iOS › TickFlow › Уведомления, чтобы получать напоминания о задачах и привычках.") }
        static var appearance: String { String(localized: "profile.appearance", defaultValue: "Оформление") }
        static var theme: String { String(localized: "profile.theme", defaultValue: "Тема") }
        static var firstWeekday: String { String(localized: "profile.firstWeekday", defaultValue: "Первый день недели") }
        static var defaultView: String { String(localized: "profile.defaultView", defaultValue: "Вид по умолчанию") }
        static var use24Hour: String { String(localized: "profile.use24Hour", defaultValue: "24-часовой формат") }
        static var taskDuration: String { String(localized: "profile.taskDuration", defaultValue: "Длительность задачи") }
        static var workingHours: String { String(localized: "profile.workingHours", defaultValue: "Рабочие часы") }
        static var notifications: String { String(localized: "profile.notifications", defaultValue: "Уведомления") }
        static var taskReminders: String { String(localized: "profile.taskReminders", defaultValue: "Напоминания о задачах") }
        static var defaultReminder: String { String(localized: "profile.defaultReminder", defaultValue: "По умолчанию") }
        static var habitReminders: String { String(localized: "profile.habitReminders", defaultValue: "Напоминания о привычках") }
        static var allowRestDays: String { String(localized: "profile.allowRestDays", defaultValue: "Разрешить дни отдыха") }
        static var skipsKeepStreak: String { String(localized: "profile.skipsKeepStreak", defaultValue: "Пропуски сохраняют серию") }
        static var dataPrivacy: String { String(localized: "profile.dataPrivacy", defaultValue: "Данные и конфиденциальность") }
        static var exportPreview: String { String(localized: "profile.exportPreview", defaultValue: "Данные TickFlow") }
        static var exportData: String { String(localized: "profile.exportData", defaultValue: "Экспорт данных") }
        static var storage: String { String(localized: "profile.storage", defaultValue: "Хранение") }
        static var onDevice: String { String(localized: "profile.onDevice", defaultValue: "На устройстве") }
        static var about: String { String(localized: "profile.about", defaultValue: "О приложении") }
        static var version: String { String(localized: "profile.version", defaultValue: "Версия") }
        static var replayOnboarding: String { String(localized: "profile.replayOnboarding", defaultValue: "Пройти знакомство заново") }
        static var loadSampleQuestion: String { String(localized: "profile.loadSampleQuestion", defaultValue: "Загрузить пример данных?") }
        static var load: String { String(localized: "profile.load", defaultValue: "Загрузить") }
        static var loadSampleMessage: String { String(localized: "profile.loadSampleMessage", defaultValue: "Добавятся категории, задачи и привычки с историей. Ваши данные останутся.") }
        static var myProfile: String { String(localized: "profile.myProfile", defaultValue: "Мой профиль") }
        static var storedOnDevice: String { String(localized: "profile.storedOnDevice", defaultValue: "Данные хранятся на этом iPhone") }
        static var viewInsights: String { String(localized: "profile.viewInsights", defaultValue: "Посмотреть аналитику") }
        static var sampleLoaded: String { String(localized: "profile.sampleLoaded", defaultValue: "Пример данных загружен") }
        static var organize: String { String(localized: "profile.organize", defaultValue: "Организация") }
    }

    enum Theme {
        static var system: String { String(localized: "theme.system", defaultValue: "Как в системе") }
        static var light: String { String(localized: "theme.light", defaultValue: "Светлая") }
        static var dark: String { String(localized: "theme.dark", defaultValue: "Тёмная") }
    }

    enum Priority {
        static var none: String { String(localized: "priority.none", defaultValue: "Без приоритета") }
        static var low: String { String(localized: "priority.low", defaultValue: "Низкий") }
        static var medium: String { String(localized: "priority.medium", defaultValue: "Средний") }
        static var high: String { String(localized: "priority.high", defaultValue: "Высокий") }
        static var lowFull: String { String(localized: "priority.lowFull", defaultValue: "Низкий приоритет") }
        static var mediumFull: String { String(localized: "priority.mediumFull", defaultValue: "Средний приоритет") }
        static var highFull: String { String(localized: "priority.highFull", defaultValue: "Высокий приоритет") }
    }

    enum Reminder {
        static var atTime: String { String(localized: "reminder.atTime", defaultValue: "В момент начала") }
        static var tenMinutes: String { String(localized: "reminder.tenMinutes", defaultValue: "За 10 минут") }
        static var oneHour: String { String(localized: "reminder.oneHour", defaultValue: "За 1 час") }
    }

    enum Repeat {
        static var never: String { String(localized: "repeat.never", defaultValue: "Никогда") }
        static var weekly: String { String(localized: "repeat.weekly", defaultValue: "Каждую неделю") }
        static var monthly: String { String(localized: "repeat.monthly", defaultValue: "Каждый месяц") }
    }

    enum HabitKind {
        static var check: String { String(localized: "habitKind.check", defaultValue: "Да / нет") }
        static var amount: String { String(localized: "habitKind.amount", defaultValue: "Количество") }
    }

    enum HabitFrequency {
        static var specificDays: String { String(localized: "habitFrequency.specificDays", defaultValue: "По дням") }
        static var weeklyGoal: String { String(localized: "habitFrequency.weeklyGoal", defaultValue: "Цель на неделю") }
    }

    enum Toast {
        static var changeUndone: String { String(localized: "toast.changeUndone", defaultValue: "Изменение отменено") }
    }

    enum Schedule {
        static func recurringQuestion(_ title: String, _ rule: String) -> String {
            String(localized: "schedule.recurringQuestion", defaultValue: "«\(title)» повторяется (\(rule)). К чему применить изменение?")
        }
        static func backToBack(_ title: String) -> String {
            String(localized: "schedule.backToBack", defaultValue: "Встык с «\(title)»")
        }
        static func shortBreak(_ minutes: Int) -> String {
            String(localized: "schedule.shortBreak", defaultValue: "Перерыв всего \(minutes) мин")
        }
    }

    enum Onboarding {
        static var skip: String { String(localized: "onboarding.skip", defaultValue: "Пропустить") }
        static var welcomeTitle: String { String(localized: "onboarding.welcomeTitle", defaultValue: "Планируйте дни спокойно.") }
        static var welcomeMessage: String { String(localized: "onboarding.welcomeMessage", defaultValue: "TickFlow хранит задачи, расписание и привычки в одном тихом месте.") }
        static var previewStandup: String { String(localized: "onboarding.previewStandup", defaultValue: "9:30  Планёрка команды") }
        static var previewLunch: String { String(localized: "onboarding.previewLunch", defaultValue: "13:30  Обед с Мией") }
        static var previewStreak: String { String(localized: "onboarding.previewStreak", defaultValue: "31 день") }
        static var featuresTitle: String { String(localized: "onboarding.featuresTitle", defaultValue: "Всё, что вы планируете, — в одном месте") }
        static var personalizeEyebrow: String { String(localized: "onboarding.personalizeEyebrow", defaultValue: "Под себя") }
        static var personalizeHint: String { String(localized: "onboarding.personalizeHint", defaultValue: "Всё необязательно. Это можно поменять в настройках.") }
        static var planStyleQuestion: String { String(localized: "onboarding.planStyleQuestion", defaultValue: "Как вы любите планировать?") }
        static var weekStarts: String { String(localized: "onboarding.weekStarts", defaultValue: "Неделя начинается") }
        static var habitGoals: String { String(localized: "onboarding.habitGoals", defaultValue: "Цели для привычек") }
        static var reminderPreviewTask: String { String(localized: "onboarding.reminderPreviewTask", defaultValue: "Дизайн-ревью через 10 минут") }
        static var reminderPreviewHabit: String { String(localized: "onboarding.reminderPreviewHabit", defaultValue: "10 минут чтения — и серия продлится до 12 дней") }
        static var remindersTitle: String { String(localized: "onboarding.remindersTitle", defaultValue: "Мягкие напоминания, только по делу") }
        static var remindersMessage: String { String(localized: "onboarding.remindersMessage", defaultValue: "Подскажем перед задачами со временем и в часы ваших привычек. Без рекламы и шума. Настроить или выключить можно позже.") }
        static var allSet: String { String(localized: "onboarding.allSet", defaultValue: "Всё готово") }
        static var planTimeBlocks: String { String(localized: "onboarding.planTimeBlocks", defaultValue: "Блоки времени") }
        static var planTodoList: String { String(localized: "onboarding.planTodoList", defaultValue: "Простой список дел") }
        static var planBoth: String { String(localized: "onboarding.planBoth", defaultValue: "Всего понемногу") }
        static var goalRead: String { String(localized: "onboarding.goalRead", defaultValue: "Больше читать") }
        static var goalMove: String { String(localized: "onboarding.goalMove", defaultValue: "Двигаться каждый день") }
        static var habitExercise: String { String(localized: "onboarding.habitExercise", defaultValue: "Зарядка") }
        static var goalSleep: String { String(localized: "onboarding.goalSleep", defaultValue: "Лучше спать") }
        static var habitBedtime: String { String(localized: "onboarding.habitBedtime", defaultValue: "Лечь до 23:00") }
        static var goalLanguage: String { String(localized: "onboarding.goalLanguage", defaultValue: "Учить язык") }
        static var habitLanguage: String { String(localized: "onboarding.habitLanguage", defaultValue: "Иностранный язык") }
        static var goalMeditate: String { String(localized: "onboarding.goalMeditate", defaultValue: "Медитировать") }
        static var featureTimeTitle: String { String(localized: "onboarding.featureTimeTitle", defaultValue: "Планируйте время") }
        static var featureTimeText: String { String(localized: "onboarding.featureTimeText", defaultValue: "День, 3 дня, неделя и месяц. Перетаскивайте задачи, растягивайте, чтобы изменить длительность.") }
        static var featureTasksTitle: String { String(localized: "onboarding.featureTasksTitle", defaultValue: "Ведите задачи") }
        static var featureTasksText: String { String(localized: "onboarding.featureTasksText", defaultValue: "Записывайте быстро. Даты, приоритеты и подзадачи — когда они нужны.") }
        static var featureHabitsTitle: String { String(localized: "onboarding.featureHabitsTitle", defaultValue: "Формируйте привычки") }
        static var featureHabitsText: String { String(localized: "onboarding.featureHabitsText", defaultValue: "Отметки, количество или минуты. Дни отдыха не прерывают серию.") }
        static var start: String { String(localized: "onboarding.start", defaultValue: "Начать") }
        static var `continue`: String { String(localized: "onboarding.continue", defaultValue: "Продолжить") }
        static var enableReminders: String { String(localized: "onboarding.enableReminders", defaultValue: "Включить напоминания") }
        static var notNow: String { String(localized: "onboarding.notNow", defaultValue: "Не сейчас") }
        static var fromMonday: String { String(localized: "onboarding.fromMonday", defaultValue: "с понедельника") }
        static var fromSunday: String { String(localized: "onboarding.fromSunday", defaultValue: "с воскресенья") }
        static var remindersOn: String { String(localized: "onboarding.remindersOn", defaultValue: "Напоминания включены. ") }
        static var remindersOff: String { String(localized: "onboarding.remindersOff", defaultValue: "Напоминания выключены — их можно включить позже в настройках. ") }
        static var startWithOne: String { String(localized: "onboarding.startWithOne", defaultValue: "Начните с одной задачи или привычки.") }
        static func summaryWeek(_ week: String, _ start: String, _ end: String) -> String {
            String(localized: "onboarding.summaryWeek", defaultValue: "Неделя начинается \(week), рабочие часы \(start) – \(end). ")
        }
        static func summaryHabits(_ habits: String) -> String {
            String(localized: "onboarding.summaryHabits", defaultValue: "Добавим \(habits) по вашим целям. ")
        }
    }

    enum Sample {
        static var work: String { String(localized: "sample.work", defaultValue: "Работа") }
        static var personal: String { String(localized: "sample.personal", defaultValue: "Личное") }
        static var health: String { String(localized: "sample.health", defaultValue: "Здоровье") }
        static var errands: String { String(localized: "sample.errands", defaultValue: "Дела") }
        static var learning: String { String(localized: "sample.learning", defaultValue: "Учёба") }
        static var teamStandup: String { String(localized: "sample.teamStandup", defaultValue: "Планёрка команды") }
        static var designReview: String { String(localized: "sample.designReview", defaultValue: "Дизайн-ревью онбординга") }
        static var designReviewNotes: String { String(localized: "sample.designReviewNotes", defaultValue: "Пройтись по новому приветственному сценарию.") }
        static var exportMockups: String { String(localized: "sample.exportMockups", defaultValue: "Экспортировать макеты") }
        static var prepareAgenda: String { String(localized: "sample.prepareAgenda", defaultValue: "Подготовить повестку") }
        static var collectFeedback: String { String(localized: "sample.collectFeedback", defaultValue: "Собрать отзывы") }
        static var quarterReport: String { String(localized: "sample.quarterReport", defaultValue: "Написать отчёт за квартал") }
        static var lunchMia: String { String(localized: "sample.lunchMia", defaultValue: "Обед с Мией") }
        static var gymUpper: String { String(localized: "sample.gymUpper", defaultValue: "Зал: верх тела") }
        static var payRent: String { String(localized: "sample.payRent", defaultValue: "Оплатить аренду") }
        static var dentist: String { String(localized: "sample.dentist", defaultValue: "Стоматолог") }
        static var designConference: String { String(localized: "sample.designConference", defaultValue: "Конференция по дизайн-системам") }
        static var designConferenceNotes: String { String(localized: "sample.designConferenceNotes", defaultValue: "Берлин. Бронь отеля в почте.") }
        static var productSync: String { String(localized: "sample.productSync", defaultValue: "Синк по продукту") }
        static var callBank: String { String(localized: "sample.callBank", defaultValue: "Позвонить в банк") }
        static var sprintPlanning: String { String(localized: "sample.sprintPlanning", defaultValue: "Планирование спринта") }
        static var spanishLesson: String { String(localized: "sample.spanishLesson", defaultValue: "Урок испанского") }
        static var groceries: String { String(localized: "sample.groceries", defaultValue: "Закупка продуктов") }
        static var oatMilk: String { String(localized: "sample.oatMilk", defaultValue: "Овсяное молоко") }
        static var coffeeBeans: String { String(localized: "sample.coffeeBeans", defaultValue: "Кофе в зёрнах") }
        static var run10k: String { String(localized: "sample.run10k", defaultValue: "Пробежка 10 км") }
        static var oneOnOneAlex: String { String(localized: "sample.oneOnOneAlex", defaultValue: "1:1 с Алексом") }
        static var readThinking: String { String(localized: "sample.readThinking", defaultValue: "Прочитать «Азбуку системного мышления»") }
        static var renewPassport: String { String(localized: "sample.renewPassport", defaultValue: "Продлить паспорт") }
        static var updatePortfolio: String { String(localized: "sample.updatePortfolio", defaultValue: "Обновить портфолио") }
        static var buyTickets: String { String(localized: "sample.buyTickets", defaultValue: "Купить билеты на декабрь") }
        static var quarterPlanning: String { String(localized: "sample.quarterPlanning", defaultValue: "Квартальное планирование") }
        static var momBirthday: String { String(localized: "sample.momBirthday", defaultValue: "День рождения мамы") }
        static var yoga: String { String(localized: "sample.yoga", defaultValue: "Йога") }
        static var carService: String { String(localized: "sample.carService", defaultValue: "ТО машины") }
        static var workshopPrep: String { String(localized: "sample.workshopPrep", defaultValue: "Подготовка к воркшопу") }
        static var codeReview: String { String(localized: "sample.codeReview", defaultValue: "Код-ревью") }
        static var pilates: String { String(localized: "sample.pilates", defaultValue: "Пилатес") }
        static var spanish: String { String(localized: "sample.spanish", defaultValue: "Испанский") }
        static var reviewMockups: String { String(localized: "sample.reviewMockups", defaultValue: "Ревью макетов") }
        static var teamSync: String { String(localized: "sample.teamSync", defaultValue: "Синк с командой") }
        static var replyEmails: String { String(localized: "sample.replyEmails", defaultValue: "Ответить на письма") }
        static var preparePresentation: String { String(localized: "sample.preparePresentation", defaultValue: "Подготовить презентацию") }
        static var callParents: String { String(localized: "sample.callParents", defaultValue: "Позвонить родителям") }
        static var sortPhotos: String { String(localized: "sample.sortPhotos", defaultValue: "Разобрать фото") }
        static var doctorAppointment: String { String(localized: "sample.doctorAppointment", defaultValue: "Записаться к врачу") }
        static var run: String { String(localized: "sample.run", defaultValue: "Пробежка") }
        static var stretching: String { String(localized: "sample.stretching", defaultValue: "Растяжка") }
        static var pool: String { String(localized: "sample.pool", defaultValue: "Бассейн") }
        static var buyGroceries: String { String(localized: "sample.buyGroceries", defaultValue: "Купить продукты") }
        static var payBills: String { String(localized: "sample.payBills", defaultValue: "Оплатить счета") }
        static var pickUpParcel: String { String(localized: "sample.pickUpParcel", defaultValue: "Забрать посылку") }
        static var bookChapter: String { String(localized: "sample.bookChapter", defaultValue: "Глава книги") }
        static var onlineCourse: String { String(localized: "sample.onlineCourse", defaultValue: "Онлайн-курс") }
    }

    enum Focus {
        static var completedTitle: String { String(localized: "focus.completedTitle", defaultValue: "Сессия фокуса завершена") }
        static func completedBody(_ minutes: Int, _ breakMinutes: Int) -> String {
            String(localized: "focus.completedBody", defaultValue: "\(minutes) мин сохранено. Время для перерыва на \(breakMinutes) мин.")
        }
        static func completedBodyTask(_ minutes: Int, _ task: String, _ breakMinutes: Int) -> String {
            String(localized: "focus.completedBodyTask", defaultValue: "\(minutes) мин на «\(task)» сохранено. Время для перерыва на \(breakMinutes) мин.")
        }
        static var breakOverTitle: String { String(localized: "focus.breakOverTitle", defaultValue: "Перерыв окончен") }
        static func breakOverBody(_ session: Int, _ total: Int) -> String {
            String(localized: "focus.breakOverBody", defaultValue: "Готовы к сессии \(session) из \(total)?")
        }
        static var button: String { String(localized: "focus.button", defaultValue: "Фокус") }
        static var timeTracking: String { String(localized: "focus.timeTracking", defaultValue: "Учёт времени") }
        static var trackingOnToast: String { String(localized: "focus.trackingOnToast", defaultValue: "Учёт времени включён для этой задачи") }
        static var trackingOffToast: String { String(localized: "focus.trackingOffToast", defaultValue: "Учёт времени выключен для этой задачи") }
        static var trackedHeader: String { String(localized: "focus.trackedHeader", defaultValue: "Потрачено") }
        static func trackedSummary(_ duration: String) -> String {
            String(localized: "focus.trackedSummary", defaultValue: "\(duration) потрачено")
        }
        static func timeLeft(_ duration: String) -> String {
            String(localized: "focus.timeLeft", defaultValue: "Осталось \(duration)")
        }
        static func overEstimate(_ duration: String) -> String {
            String(localized: "focus.overEstimate", defaultValue: "\(duration) сверх оценки")
        }
        static var noEstimate: String { String(localized: "focus.noEstimate", defaultValue: "Без оценки") }
        static var estimate: String { String(localized: "focus.estimate", defaultValue: "Оценка") }
        static var startFocus: String { String(localized: "focus.startFocus", defaultValue: "Начать фокус") }
        static var startTimer: String { String(localized: "focus.startTimer", defaultValue: "Таймер") }
        static var addManually: String { String(localized: "focus.addManually", defaultValue: "Добавить вручную") }
        static func showAll(_ count: Int) -> String {
            String(localized: "focus.showAll", defaultValue: "Показать все (\(count))")
        }
        static var showLess: String { String(localized: "focus.showLess", defaultValue: "Свернуть") }
        static var phaseFocus: String { String(localized: "focus.phaseFocus", defaultValue: "Фокус") }
        static var phaseTimer: String { String(localized: "focus.phaseTimer", defaultValue: "Таймер") }
        static var phaseShortBreak: String { String(localized: "focus.phaseShortBreak", defaultValue: "Короткий перерыв") }
        static var phaseLongBreak: String { String(localized: "focus.phaseLongBreak", defaultValue: "Длинный перерыв") }
        static var pausedSuffix: String { String(localized: "focus.pausedSuffix", defaultValue: " · Пауза") }
        static var readySuffix: String { String(localized: "focus.readySuffix", defaultValue: " · Готов") }
        static var kindFocus: String { String(localized: "focus.kindFocus", defaultValue: "Фокус") }
        static var kindTimer: String { String(localized: "focus.kindTimer", defaultValue: "Таймер") }
        static var kindManual: String { String(localized: "focus.kindManual", defaultValue: "Вручную") }
        static var kindBreak: String { String(localized: "focus.kindBreak", defaultValue: "Перерыв") }
        static var statusCompleted: String { String(localized: "focus.statusCompleted", defaultValue: "Завершена") }
        static var statusInterrupted: String { String(localized: "focus.statusInterrupted", defaultValue: "Прервана") }
        static var statusCancelled: String { String(localized: "focus.statusCancelled", defaultValue: "Отброшена") }
        static var statusRunning: String { String(localized: "focus.statusRunning", defaultValue: "Идёт") }
        static var pause: String { String(localized: "focus.pause", defaultValue: "Пауза") }
        static var resume: String { String(localized: "focus.resume", defaultValue: "Продолжить") }
        static var stop: String { String(localized: "focus.stop", defaultValue: "Стоп") }
        static func startTimerFor(_ task: String) -> String {
            String(localized: "focus.startTimerFor", defaultValue: "Запустить таймер: \(task)")
        }
        static var openTimer: String { String(localized: "focus.openTimer", defaultValue: "Открыть таймер") }
        static var noTaskLink: String { String(localized: "focus.noTaskLink", defaultValue: "Без задачи · Привязать") }
        static func minuteSession(_ minutes: Int) -> String {
            String(localized: "focus.minuteSession", defaultValue: "Сессия на \(minutes) мин")
        }
        static func ofMinutes(_ minutes: Int) -> String {
            String(localized: "focus.ofMinutes", defaultValue: "из \(minutes) мин")
        }
        static func timerOfEstimate(_ tracked: String, _ estimate: String) -> String {
            String(localized: "focus.timerOfEstimate", defaultValue: "\(tracked) из \(estimate) по оценке")
        }
        static func timerOnTask(_ tracked: String) -> String {
            String(localized: "focus.timerOnTask", defaultValue: "\(tracked) на этой задаче")
        }
        static func sessionOf(_ session: Int, _ total: Int) -> String {
            String(localized: "focus.sessionOf", defaultValue: "Сессия \(session) из \(total)")
        }
        static func sessionsDone(_ done: Int, _ total: Int) -> String {
            String(localized: "focus.sessionsDone", defaultValue: "Выполнено \(done) из \(total)")
        }
        static var longBreakCycle: String { String(localized: "focus.longBreakCycle", defaultValue: "Длинный перерыв · цикл пройден") }
        static var start: String { String(localized: "focus.start", defaultValue: "Старт") }
        static var startBreak: String { String(localized: "focus.startBreak", defaultValue: "Начать перерыв") }
        static var stopAndSave: String { String(localized: "focus.stopAndSave", defaultValue: "Стоп и сохранить") }
        static var endCycle: String { String(localized: "focus.endCycle", defaultValue: "Завершить цикл") }
        static var skipBreak: String { String(localized: "focus.skipBreak", defaultValue: "Пропустить перерыв") }
        static var presetCustom: String { String(localized: "focus.presetCustom", defaultValue: "Свой") }
        static func sessions(_ count: Int) -> String {
            String(localized: "focus.sessions", defaultValue: "\(count) сессии")
        }
        static func todaySummary(_ duration: String, _ sessions: String) -> String {
            String(localized: "focus.todaySummary", defaultValue: "Сегодня · \(duration) фокуса · \(sessions)")
        }
        static var history: String { String(localized: "focus.history", defaultValue: "История") }
        static var endSessionTitle: String { String(localized: "focus.endSessionTitle", defaultValue: "Завершить сессию?") }
        static func endSessionMessage(_ minutes: Int, _ total: Int) -> String {
            String(localized: "focus.endSessionMessage", defaultValue: "Вы сосредоточены \(minutes) из \(total) мин. Сохраните сессию как прерванную или удалите её.")
        }
        static func saveMinutes(_ minutes: Int) -> String {
            String(localized: "focus.saveMinutes", defaultValue: "Сохранить \(minutes) мин")
        }
        static var discardSession: String { String(localized: "focus.discardSession", defaultValue: "Удалить сессию") }
        static func savedInterruptedToast(_ minutes: Int) -> String {
            String(localized: "focus.savedInterruptedToast", defaultValue: "Сохранено \(minutes) мин · Прервана")
        }
        static var cycleEndedToast: String { String(localized: "focus.cycleEndedToast", defaultValue: "Цикл фокуса завершён") }
        static var linkTask: String { String(localized: "focus.linkTask", defaultValue: "Привязать задачу") }
        static var noTask: String { String(localized: "focus.noTask", defaultValue: "Без задачи") }
        static var focusSession: String { String(localized: "focus.focusSession", defaultValue: "Сессия фокуса") }
        static var manualEntry: String { String(localized: "focus.manualEntry", defaultValue: "Ручная запись") }
        static var timerSettingsTitle: String { String(localized: "focus.timerSettingsTitle", defaultValue: "Таймер фокуса") }
        static var preset: String { String(localized: "focus.preset", defaultValue: "Пресет") }
        static var longBreakAfter: String { String(localized: "focus.longBreakAfter", defaultValue: "Длинный перерыв после") }
        static var autoStartBreaks: String { String(localized: "focus.autoStartBreaks", defaultValue: "Автозапуск перерывов") }
        static var autoStartFocus: String { String(localized: "focus.autoStartFocus", defaultValue: "Автозапуск фокуса") }
        static var sessionNotifications: String { String(localized: "focus.sessionNotifications", defaultValue: "Уведомления о сессиях") }
        static var settingsFootnote: String { String(localized: "focus.settingsFootnote", defaultValue: "Таймер идёт в фоне. Когда сессия или перерыв закончатся, придёт уведомление.") }
        static var addTime: String { String(localized: "focus.addTime", defaultValue: "Добавить время") }
        static var editEntry: String { String(localized: "focus.editEntry", defaultValue: "Изменить запись") }
        static var saveTime: String { String(localized: "focus.saveTime", defaultValue: "Сохранить время") }
        static var task: String { String(localized: "focus.task", defaultValue: "Задача") }
        static var duration: String { String(localized: "focus.duration", defaultValue: "Длительность") }
        static var endBeforeStart: String { String(localized: "focus.endBeforeStart", defaultValue: "Конец раньше начала.") }
        static var footTimer: String { String(localized: "focus.footTimer", defaultValue: "Время записано таймером. Поправьте его, если забыли остановить.") }
        static var footManual: String { String(localized: "focus.footManual", defaultValue: "Ручные записи входят в потраченное время задачи и видны в календаре.") }
        static var deleteEntry: String { String(localized: "focus.deleteEntry", defaultValue: "Удалить запись") }
        static var discard: String { String(localized: "focus.discard", defaultValue: "Не сохранять") }
        static func entrySavedToast(_ duration: String) -> String {
            String(localized: "focus.entrySavedToast", defaultValue: "Запись сохранена · \(duration)")
        }
        static func entryUpdatedToast(_ duration: String) -> String {
            String(localized: "focus.entryUpdatedToast", defaultValue: "Запись изменена · \(duration)")
        }
        static var entryDeletedToast: String { String(localized: "focus.entryDeletedToast", defaultValue: "Запись удалена") }
        static var sessionTitle: String { String(localized: "focus.sessionTitle", defaultValue: "Сессия") }
        static var actual: String { String(localized: "focus.actual", defaultValue: "Фактически") }
        static var plan: String { String(localized: "focus.plan", defaultValue: "План") }
        static var totalOnTask: String { String(localized: "focus.totalOnTask", defaultValue: "Всего на задаче") }
        static func totalOf(_ tracked: String, _ estimate: String) -> String {
            String(localized: "focus.totalOf", defaultValue: "\(tracked) из \(estimate)")
        }
        static var openTask: String { String(localized: "focus.openTask", defaultValue: "Открыть задачу") }
        static var deleteSession: String { String(localized: "focus.deleteSession", defaultValue: "Удалить сессию") }
        static var sessionDeletedToast: String { String(localized: "focus.sessionDeletedToast", defaultValue: "Сессия удалена") }
        static var openFocus: String { String(localized: "focus.openFocus", defaultValue: "Открыть фокус") }
        static var settings: String { String(localized: "focus.settings", defaultValue: "Настройки таймера") }
    }
}
