# TickFlow — план покрытия юнит-тестами

План шёл от дешёвой чистой логики к view model: каждый этап сам по себе приносит пользу
и вливался отдельным PR.

> **Статус: этапы 0–4 выполнены.** 553 теста (Swift Testing) в `TickFlowTests/`, все цели покрытия достигнуты.
> Осталось только CI (см. «Отложено: CI»). UI- и snapshot-тесты — вне плана.

**Цели покрытия** (`xcodebuild test -enableCodeCoverage YES`):

| Слой | Цель |
|---|---|
| `Models/`, `Shared/`, `TimeGridLayout`, `DateSelection` | ≥ 90 % |
| `Repositories/`, `ExportService` | ≥ 80 % |
| ViewModel экранов | ≥ 70 % |
| SwiftUI View, `DesignSystem/`, `SeedService` | не покрываем юнит-тестами |

---

## Этап 0. Инфраструктура и подготовка кода

> **Готово.** Таргет `TickFlowTests` в схеме, покрытие собирается только по `TickFlow`.
> `AppClock` / `SystemClock`, `ReminderScheduling` / `SystemReminderScheduler` внедряются через `AppDependencies`
> в репозитории и ViewModel (по умолчанию — системные реализации). Часы передаются в `DisplayFormatter`,
> поэтому «сегодня» во всех экранах берётся из них. Под тестами `TickFlowApp` не создаёт базу и зависимости.
> Помощники: `TestCalendar`, `date(_:)`, `FixedClock`, `makeInMemoryContainer()`, `makeIsolatedDefaults()`,
> `FakeTaskRepository` (заодно `TaskListRepository`), `FakeHabitRepository`, `FakeSettingsRepository`, `FakeReminderScheduler`.
> Дымовые тесты — `InfrastructureTests`.
> Осталось на `Calendar.current` / `.now`: статический `DateFormatting` в `Theme.swift`, `TaskEditorRequest.new(day:)`,
> `TaskDraft.hasSameSchedule` и `NotificationScheduler` (он за протоколом). Чинить при тестах этапа 1, если понадобится.

### 0.1 Таргет
- Добавить таргет `TickFlowTests` (Unit Testing Bundle, **Swift Testing**: `@Test`, `#expect`), host — `TickFlow`, `@testable import TickFlow`.
- Включить таргет в схему `TickFlow`, включить сбор покрытия.
- Папка `TickFlowTests/` — синхронизированная группа, как основной таргет.
- Запуск: `xcodebuild test -project TickFlow.xcodeproj -scheme TickFlow -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -enableCodeCoverage YES`. Без `OS=` берётся последняя версия, а на ней такого симулятора может не быть.
- На тестовом запуске не выполнять `bootstrap()` / сид примера данных (проверять `XCTestConfigurationFilePath` или аргумент запуска), чтобы приложение-хост не трогало UserDefaults и уведомления.

### 0.2 Общие помощники (`TickFlowTests/Support/`)
- `TestCalendar` — григорианский календарь с фиксированными часовым поясом (`Europe/Moscow` и отдельно зона с переходом на летнее время, например `Europe/Berlin`), локалью и `firstWeekday` (понедельник / воскресенье).
- `date("2026-11-08 09:30")` — короткая фабрика дат.
- `makeInMemoryContainer()` — `ModelContainer` с `isStoredInMemoryOnly: true` для всех моделей.
- Фейки: `FakeTaskRepository`, `FakeHabitRepository`, `FakeSettingsRepository` (запоминают вызовы и аргументы), `FakeReminderScheduler`.
- `UserDefaults(suiteName: UUID().uuidString)` для `UserDefaultsSettingsRepository`.

### 0.3 Рефакторинг для тестируемости (небольшой, без изменения поведения)
1. **Текущее время.** `.now` / `Date()` берутся напрямую в `TaskItem` (`isOverdue`, `reminderDate`), `Habit`, `SwiftDataRepository`, `CalendarViewModel`, `TaskEditorViewModel`, `HabitDetailViewModel`, `SettingsViewModel`, `DateSelection`. Ввести `protocol AppClock { var now: Date { get } }` (или `() -> Date`), передавать через `AppDependencies`; в моделях — параметр `now: Date = .now`.
2. **Календарь.** Там, где используется `Calendar.current` без параметра (`TaskItem.isOverdue`, `apply(_:to:)` в репозитории), принимать календарь снаружи.
3. **Уведомления.** `NotificationScheduler` — статический enum, его вызывают оба репозитория, `SettingsViewModel` и `OnboardingViewModel`. Вынести `protocol ReminderScheduling` (`reschedule`, `cancel`, `scheduleHabit`, `cancelHabit`, `requestAuthorization`) и передавать в репозитории; в тестах — `FakeReminderScheduler`.

---

## Этап 1. Чистая логика (самая высокая ценность, без зависимостей)

> **Готово.** 227 тестов (вместе с `InfrastructureTests`). Покрытие: `ConflictDetector`, `TimeGridLayout`, `DateSelection`,
> `TaskRowItem`, `TaskFilterStore`, `AppSettings`, `TaskOptions`, `AppNavigator` — 100 %; `DisplayFormatter` 97 %,
> `Habit` 97 %, `ToastCenter` 95 %, `TaskItem` 94 %, `ScheduleCommit` 94 %, `HabitHistory` 92 %.
> Тесты идут на русском: язык и регион тестового запуска заданы в схеме (`ru` / `RU`).
> Для этого в коде: `DisplayFormatter` принимает `locale`, `ToastCenter` — функцию задержки (в тестах `ManualSleeper`),
> `ConflictDetector.conflict(for:in:calendar:)`, `gapNote` и `dueLabel` больше не берут `Calendar.current`.
> `L10nTests` читают `L10n.swift` и `Localizable.xcstrings` по `#filePath` — работает в симуляторе, не на устройстве.
> Зафиксированное поведение: ежемесячный повтор после 31 янв. → 28 фев. продолжается с 28-го (28 мар.).

| Тестовый файл | Что проверяем | Ключевые случаи |
|---|---|---|
| `RepeatRuleTests` | `RepeatRule.nextDate` | `never` → `nil`; daily через конец месяца и года; weekly; monthly 31 янв → 28 фев (и 29 фев в високосный), зафиксировать текущее поведение для следующего шага (28 мар); weekdays: пт → пн, сб → пн; переход на летнее время сохраняет время суток |
| `TaskItemTests` | `occurs(on:)`, `endDate`, `isOverdue`, `reminderDate`, `setCompleted`, `moveToToday`, `completedSubtaskCount`, `sortedSubtasks` | без даты → не встречается; многодневная задача: первый, средний, последний день, день после; сегодняшняя не просрочена, вчерашняя — да, выполненная — никогда; напоминание в прошлом → `nil`; без времени → нет `endDate` и напоминания |
| `HabitTests` | `isScheduled(on:)`, `log(on:)` | ежедневно / по дням недели / N раз в неделю; поиск лога по дню независимо от времени |
| `HabitHistoryTests` | `state(on:)`, `value`, `isDone`, `isSkipped`, `completion(from:to:)`, `stats` (серия, лучшая серия, процент) | количественная привычка (частично / полностью); пропуск при `skippedKeepStreak` true/false; день не по расписанию не рвёт серию; сегодня ещё не отмечено — серия не сброшена; будущие дни не считаются; недельная частота: подсчёт по неделям с учётом `firstWeekday` |
| `HabitTextTests` | `value`, `unit`, `schedule`, `target`, `streak` | дробные значения; формы «1 день / 2 дня / 5 дней» |
| `ConflictDetectorTests` | `conflict(...)`, `conflict(for:in:)` | пересечение; касание встык — не конфликт; выполненные, многодневные и без времени игнорируются; задача не конфликтует сама с собой |
| `TimeGridLayoutTests` | `place(_:)`, `lanes(for:)`, `TimelineGeometry` | одиночная задача — ширина 100 %; две пересекающиеся — две колонки; цепочка A∩B, B∩C, A∦C; кластеры не влияют друг на друга; `snappedMinutes` округляет к шагу; `slotMinute(atY:)` на границах суток; геометрия для каждого `CalendarMode` |
| `DateSelectionTests` | `isMultiDay`, `startDate`, `endDate`, `isInvalid` | конец раньше начала → невалидно; один день; через полночь |
| `DisplayFormatterTests` | все методы | 24-часовой и 12-часовой формат; `duration` (45 мин, 1 ч, 1 ч 30 мин); `relativeDay` (вчера / сегодня / завтра / дата); `monthTitle` с годом и без; `dueLabel` для задачи без времени, со временем, многодневной; ru и en локали |
| `AppSettingsTests` | `Codable` | кодирование туда-обратно; декодирование старого JSON без новых ключей → значения по умолчанию; неизвестные ключи не ломают декодирование |
| `ScheduleCommitTests` | `gapNote`, `recurringMessage` | «Встык с …», «Перерыв всего N мин», нет соседей → пустая строка; исключение текущей задачи |
| `TaskFilterStoreTests` | `matches`, `toggleCategory`, `reset` | статусы все / открытые / выполненные × выбранные категории |
| `TaskRowItemTests` | сборка строки | подзадачи «2/3», флаги напоминания, повтора, пересечения, просрочки |
| `ToastCenterTests` | `show`, `performUndo`, `dismiss` | новый тост заменяет старый; undo вызывает замыкание один раз и показывает «Изменение отменено»; без undo кнопки нет. Таймер 4,5 с — через внедряемую задержку |
| `AppNavigatorTests` | `openNewTask`, `openNewHabit`, `openSettings` | правильная вкладка и флаг запроса |

### Локализация (`L10nTests`)
- Каждый ключ из `L10n.swift` есть в `Localizable.xcstrings` и имеет `ru` и `en` (тест читает каталог из бандла как JSON).
- Число и типы плейсхолдеров (`%@`, `%lld`) совпадают в `ru` и `en`.
- Plural: `L10n.Plural.days` для 1, 2, 5, 11, 21, 22, 25, 111 в ru; 1 и 2 в en.
- Функции с параметрами подставляют все аргументы (нет «%@» в результате).

---

## Этап 2. Репозитории и сервисы (SwiftData в памяти)

> **Готово.** 56 тестов, всего 283. Покрытие: `SwiftDataRepository` 98 %, `SwiftDataHabitRepository` 96 %,
> `UserDefaultsSettingsRepository`, `TaskDraft`, `ExportService` — 100 % (включая `ExportFile` через `exported(as:)`).
> `ExportService.makeJSON` принимает `exportedAt`, `SettingsViewModel` передаёт время из часов.
> `SystemReminderScheduler` не покрыт — это тонкая обёртка над `UNUserNotificationCenter` (см. «Не входит в план»).
> Зафиксированное текущее поведение (если оно не задумано — отдельная правка):
> - `duplicate` копирует отметки подзадач как есть, сбрасывает только выполнение самой задачи;
> - пропуск дня привычки обнуляет уже внесённое значение;
> - `setDuration` не перепланирует напоминание (оно зависит только от начала);
> - удаление категории каскадно удаляет её задачи и снимает их напоминания.

| Тестовый файл | Что проверяем | Ключевые случаи |
|---|---|---|
| `SwiftDataRepositoryTests` | `save(_:to:)` | новая задача и редактирование; подзадачи: добавление, удаление, порядок; категория; `sortOrder` растёт |
| | `setCompleted` | обычная задача; **повторяющаяся**: выполненное вхождение остаётся с `repeatRule = .never`, создаётся следующее с той же категорией, временем и подзадачами (сброшенными); снятие отметки не создаёт новое |
| | `delete` + `restore(snapshot)` | восстановление всех полей и подзадач (основа «Отменить») |
| | `duplicate`, `schedule(at:)`, `setDuration`, `setDays`, `moveToToday` | длительность сохраняется при переносе; многодневность; перенос просроченной на сегодня с сохранением времени |
| | напоминания | после каждой операции — корректный вызов `FakeReminderScheduler` (`reschedule` с датой / `cancel`); `rescheduleReminders(enabled: false)` снимает все |
| | категории | `save` списка; `delete` списка отменяет напоминания его задач и удаляет их (зафиксировать каскад) |
| `SwiftDataHabitRepositoryTests` | `save`, `delete`, `setValue`, `setSkipped`, `rescheduleReminders` | лог создаётся один на день; повторная запись обновляет; пропуск сбрасывает значение (или нет — зафиксировать); напоминания по дням недели |
| `UserDefaultsSettingsRepositoryTests` | `update`, загрузка | изменения сохраняются и читаются новым экземпляром; повреждённые данные → настройки по умолчанию |
| `ExportServiceTests` | `makeJSON` | структура архива, даты в ISO 8601, подзадачи и логи привычек на месте, пустая база → валидный JSON |

---

## Этап 3. ViewModel (фейки репозиториев, фиксированные часы)

> **Готово.** 220 тестов, всего 503. Покрытие всех ViewModel — 90–100 %: `TaskEditor` 96 %, `Calendar` 96 %,
> `DateTimePicker` 91 %, `Tasks` 99 %, `Habits` 99 %, `HabitDetail` 94 %, `HabitEditor` 99 %, `Insights` 95 %,
> `Settings` 98 %, `Onboarding` 99 %, `Search`, `FilterSheet`, `Root` 100 %, `ListEditor` 98 %.
>
> Решения:
> - Тестовый запуск закреплён на `TZ=Europe/Moscow` (env в TestAction схемы). ViewModel берут `Calendar.current`,
>   поэтому без этого даты зависели бы от машины. Проверяет `InfrastructureTests.testRunEnvironmentIsPinned`.
> - Экраны привычек тестируются с настоящим `SwiftDataHabitRepository` в памяти: статистика зависит от того, как
>   репозиторий хранит отметки (удаление при 0, сброс пропуска). Остальные ViewModel работают с фейками.
> - `QuickTaskPanel.swift` показывает низкое покрытие, потому что в нём лежит SwiftUI-вид; сам `QuickEditorHost` покрыт полностью.
>
> Найденные и исправленные ошибки:
> - `HabitsViewModel.tap`: если на сегодня уже была отметка (частичный прогресс или пропуск), после
>   выполнения не показывался тост с «Отменить». `HabitHistory` держит ссылки на живые `HabitLog`,
>   поэтому `before.isDone` читался уже после изменения. Теперь флаг запоминается до `setValue`.
> - `insights.deltaPercent`: в каталоге стоял одиночный `%`, и знак процента пропадал («+100 к прошлому периоду»).
>   Исправлено на `%%` (ru и en); `L10nTests.literalPercentIsEscaped` проверяет весь каталог.
>
> Текущее поведение, зафиксированное тестами (возможно, стоит поменять):
> - Имя файла экспорта берёт дату в UTC: ночью по Москве это вчерашний день (`TickFlow-2026-11-07.json` в 01:00 08.11).
> - У новой привычки без серии подпись «Ещё 0 дней до рекорда».

Порядок — по сложности логики и риску регрессий.

1. **`DateTimePickerViewModel`**
   - Шаги: ±15 мин / ±1 день, ограничения длительности, всего дня.
   - Колесо точного времени: `openWheel` для начала / конца выставляет `wheelDayIndex`, `wheelHour`, `wheelMinute`; `applyWheel` для начала сдвигает конец с сохранением длительности; для конца — меняет длительность; `isWheelInvalid`, когда конец раньше начала; `cancelWheel` ничего не меняет; `wheelSummary`; границы 181 дня.
2. **`TaskEditorViewModel`**
   - Пустое название → сохранение недоступно; создание и редактирование передают в репозиторий правильный `TaskDraft`.
   - Быстрый режим (Quick panel); повторяющаяся задача → выбор «только эта / эта и следующие»; предупреждение о пересечении.
3. **`CalendarViewModel`**
   - `swipe(dx:dy:)`: месяц ±1 в режиме «Месяц», неделя ±7 дней в режиме «День»; порог и направление.
   - Перетаскивание: перенос с привязкой к шагу, изменение длительности, перенос между днями; `overlapMessage`; `nowRange`; «Отменить» возвращает исходное время.
   - Дни месяца: начало недели с понедельника / воскресенья, точки задач.
4. **`TasksViewModel`** — группы «Просрочено / Сегодня / Предстоящие / Без даты / Выполненные», сортировка, сворачивание, компактный вид, `doneOfTotal`, фильтр, `movedTo`.
5. **`HabitsViewModel`, `HabitDetailViewModel`, `HabitEditorViewModel`** — отметка за день, количественный ввод, пропуск, статистика экрана, валидация редактора, дни недели.
6. **`InsightsViewModel`** — агрегаты за неделю / месяц, дельты к прошлому периоду (рост, падение, деление на ноль), разбивка по дням и категориям.
7. **`SearchViewModel`, `FilterSheetViewModel`, `ListEditorViewModel`** — поиск по названию и заметкам без учёта регистра, пустой запрос, применение фильтра, валидация категории.
8. **`SettingsViewModel`, `OnboardingViewModel`, `RootViewModel`** — смена темы и формата времени попадает в репозиторий; `replayOnboarding` переключает на вкладку «Задачи» и ставит флаг; онбординг: шаги, выбор стиля планирования, запрос уведомлений через фейк.
9. **`QuickEditorHost`** — `show` / `close` / `finishClose`, флаг `isClosing`.

---

## Этап 4. Фокус и учёт времени

> **Готово** вместе с самой функцией. Движок фокуса тестируется с `FixedClock`, `autoTick: false`
> (время двигает тест и вызывает `refresh()`), `FakeFocusAlertScheduler` и отдельным `UserDefaults`.

| Тестовый файл | Что проверяем | Ключевые случаи |
|---|---|---|
| `TimeTrackingModelTests` | `TimeEntry`, `TaskItem.tracksTime`, `effectiveEstimate`, `trackedMinutes`, `FocusSettings` | своё значение учёта важнее категории; оценка по слоту и `0` — без оценки; перерывы и отменённые не входят в потраченное; пресеты и старый JSON без `focus` |
| `SwiftDataTimeEntryRepositoryTests` | `add`, `update`, `delete`, `entries(for:)`, `entries(on:)` | неверный интервал не сохраняется; вид при правке не меняется; удаление задачи оставляет записи без задачи; восстановление задачи возвращает связь |
| `FocusEngineTests` | `FocusEngine`, `FocusRun` | фазы и длинный перерыв; автозапуск; пауза не входит в длительность; порог 30 с; «Стоп» для фокуса, перерыва и таймера; новая сессия сохраняет старую; пропущенные в фоне фазы; восстановление после перезапуска; уведомление о конце фазы; без уведомлений нет и баннера |
| `TaskTimeTrackingTests` | строка задачи и блок «Потрачено» редактора | кнопка таймера только при включённом учёте; переключатель учёта с тостом; шаг оценки; три записи и «Показать все» |
| `CategoriesViewModelTests` | экран «Категории», «Учитывать время по умолчанию» | число открытых задач; подпись о задачах со своим значением; новая категория из редактора задачи выбирается сразу |
| `FocusScreensTests` | `FocusScreenViewModel`, `FocusStopFlow`, `TimeEntryEditorViewModel`, `SessionDetailViewModel`, `FocusSettingsViewModel` | готовый экран с пресетами; пресет меняет не начатую фазу; точки цикла и перерыв; «Стоп» → прерванная запись или лист таймера; свайп листа таймера продолжает таймер; ручная запись, конец раньше начала, нет будущих дней, запись через полночь; удаление из правки закрывает лист сессии; границы настроек |
| `CalendarTrackingTests` | полосы на шкале, месяц, «Учтённое время» | только записи работы; колонки с полосой; перерыв не «идёт»; подпись «1ч10мин» в месяце; редактор задачи открывается после закрытия листа сессии |
| `FocusHistoryTests` | `FocusHistoryViewModel`, `TimeReport` | итоги 7 дней; дни новые сверху; фильтр; «Показать более ранние»; KPI, доля фокуса, категории и оценка с фактом |

Изменённые тесты: `ExportServiceTests` (записи времени и поля учёта), `SeedServiceTests` (пример содержит записи),
`SearchFilterListEditorTests` (учёт по умолчанию в редакторе категории), `SettingsOnboardingRootTests` (группа «Категории» ушла в отдельный экран).

---

## Не входит в план
- Вёрстка SwiftUI и анимации. Позже можно добавить UI-тесты для сценариев «создать задачу», «перетащить в календаре», «отметить привычку» и snapshot-тесты для светлой и тёмной темы.
- Реальная работа `UNUserNotificationCenter` (за протоколом `ReminderScheduling`).
- `SeedService` — только дымовые тесты (`SeedServiceTests`, **готово**, покрытие 98 %): сид в пустую базу создаёт
  категории, задачи с историей и привычки с отметками; данные согласованы (у каждой задачи есть категория,
  `sortOrder` уникален, многодневные заканчиваются позже начала); при непустой базе `seedIfNeeded` ничего не делает;
  «Загрузить пример» поверх своих данных не дублирует категории и привычки, а задачи встают после своих.
  `SeedService` берёт `Calendar.current` и `.now`, поэтому конкретные даты не проверяются.

## Порядок работ и оценка

| Этап | Объём (план) | Оценка | Факт |
|---|---|---|---|
| 0. Таргет, помощники, часы, `ReminderScheduling` | ~6 файлов | 0,5–1 день | готово, 8 файлов помощников |
| 1. Чистая логика + локализация | ~16 файлов, ~150 тестов | 2 дня | готово, 227 тестов |
| 2. Репозитории и экспорт | 4 файла, ~50 тестов | 1–1,5 дня | готово, 56 тестов |
| 3. ViewModel | ~12 файлов, ~120 тестов | 3–4 дня | готово, 220 тестов |
| `SeedService` (дымовые) | 1 файл | — | готово, 5 тестов |
| **Всего** | | | **508 тестов** |

## Отложено: CI

Пока не настроено, сделаем позже. Цель — запускать тесты на каждый PR в `main`.

- GitHub Actions, workflow `.github/workflows/tests.yml`, триггеры `pull_request` и `push` в `main`.
- Runner `macos` с Xcode 27 (`maxim-lobanov/setup-xcode` или выбор через `xcode-select`). Проект требует iOS 26.
- Команда: `xcodebuild test -project TickFlow.xcodeproj -scheme TickFlow -destination 'platform=iOS Simulator,name=<iPhone>,OS=<версия>' -enableCodeCoverage YES`.
  Имя и версию симулятора брать из образа runner'а (`xcrun simctl list devices available`): без `OS=` берётся последняя версия, а на ней нужного устройства может не быть.
- Подпись не нужна: для симулятора достаточно `CODE_SIGNING_ALLOWED=NO`.
- Язык тестов уже задан в схеме (`ru` / `RU`) — на runner'е отдельно настраивать не нужно.
- `L10nTests` читают исходники по `#filePath`, поэтому тесты должны идти из checkout'а репозитория (не из собранного заранее бандла).
- Результат: `.xcresult` как артефакт; отчёт о покрытии — `xcrun xccov view --report`. Порог покрытия как проверку PR можно добавить позже.
