import Foundation
import Observation
import UIKit

/// Настройки: оформление, календарь, уведомления, категории, привычки и данные.
@MainActor
@Observable
final class SettingsViewModel {
    var isLoadSampleConfirmationPresented = false
    private(set) var notificationsDenied = false

    @ObservationIgnored private let settings: any SettingsRepository
    @ObservationIgnored private let tasks: any TaskRepository
    @ObservationIgnored private let lists: any TaskListRepository
    @ObservationIgnored private let habits: any HabitRepository
    @ObservationIgnored private let timeEntries: any TimeEntryRepository
    @ObservationIgnored private let toasts: ToastCenter
    @ObservationIgnored private let navigator: AppNavigator
    @ObservationIgnored private let loadSampleData: () -> Void
    @ObservationIgnored private let clock: any AppClock
    @ObservationIgnored private let reminders: any ReminderScheduling

    init(
        settings: any SettingsRepository,
        tasks: any TaskRepository,
        lists: any TaskListRepository,
        habits: any HabitRepository,
        timeEntries: any TimeEntryRepository,
        toasts: ToastCenter,
        navigator: AppNavigator,
        loadSampleData: @escaping () -> Void,
        clock: any AppClock = SystemClock(),
        reminders: any ReminderScheduling = SystemReminderScheduler()
    ) {
        self.clock = clock
        self.reminders = reminders
        self.settings = settings
        self.tasks = tasks
        self.lists = lists
        self.habits = habits
        self.timeEntries = timeEntries
        self.toasts = toasts
        self.navigator = navigator
        self.loadSampleData = loadSampleData
    }

    private var current: AppSettings { settings.settings }

    // MARK: - Оформление

    var themeOptions: [AppTheme] { AppTheme.allCases }

    var theme: AppTheme {
        get { current.theme }
        set { settings.update { $0.theme = newValue } }
    }

    // MARK: - Календарь

    var weekdayOptions: [(value: Int, title: String)] { [(2, L10n.Common.monday), (1, L10n.Common.sunday)] }

    var firstWeekday: Int {
        get { current.firstWeekday }
        set { settings.update { $0.firstWeekday = newValue } }
    }

    var calendarModeOptions: [(value: CalendarMode, title: String)] {
        [(.day, L10n.Calendar.day), (.threeDay, L10n.Calendar.threeDays), (.week, L10n.Calendar.week), (.month, L10n.Calendar.month)]
    }

    var defaultCalendarMode: CalendarMode {
        get { current.defaultCalendarMode }
        set {
            settings.update {
                $0.defaultCalendarMode = newValue
                $0.lastCalendarMode = newValue
            }
        }
    }

    var uses24HourTime: Bool {
        get { current.uses24HourTime }
        set { settings.update { $0.uses24HourTime = newValue } }
    }

    var durationOptions: [(value: Int, title: String)] {
        [15, 30, 45, 60, 90].map { ($0, DateFormatting.duration(minutes: $0)) }
    }

    var defaultTaskDuration: Int {
        get { current.defaultTaskDuration }
        set { settings.update { $0.defaultTaskDuration = newValue } }
    }

    var workdayStartLabel: String { format.time(minute: current.workdayStartHour * 60) }
    var workdayEndLabel: String { format.time(minute: current.workdayEndHour * 60) }

    func shiftWorkdayStart(_ delta: Int) {
        settings.update { $0.workdayStartHour = min(max(0, $0.workdayStartHour + delta), $0.workdayEndHour - 1) }
    }

    func shiftWorkdayEnd(_ delta: Int) {
        settings.update { $0.workdayEndHour = min(max($0.workdayStartHour + 1, $0.workdayEndHour + delta), 24) }
    }

    // MARK: - Уведомления

    var taskRemindersEnabled: Bool {
        get { current.taskRemindersEnabled && !notificationsDenied }
        set {
            settings.update { $0.taskRemindersEnabled = newValue }
            tasks.rescheduleReminders(enabled: newValue)
        }
    }

    var reminderOptions: [ReminderOption] { ReminderOption.allCases }

    var defaultReminder: ReminderOption {
        get { current.defaultReminder }
        set { settings.update { $0.defaultReminder = newValue } }
    }

    var habitRemindersEnabled: Bool {
        get { current.habitRemindersEnabled && !notificationsDenied }
        set {
            settings.update { $0.habitRemindersEnabled = newValue }
            habits.rescheduleReminders(enabled: newValue)
        }
    }

    /// Проверяет, не запрещены ли уведомления в системных настройках.
    func refreshAuthorization() async {
        notificationsDenied = await reminders.isDenied()
    }

    // MARK: - Категории

    /// Сколько категорий — значение строки «Категории».
    var categoryCount: String { String(lists.lists.count) }

    /// «25/5», «50/10» или «40/7 мин».
    var focusTimerSummary: String { FocusSettingsViewModel.summary(current.focus) }
    var isFocusSettingsPresented = false

    var wantsFocusHistory: Bool { navigator.wantsFocusHistory }

    /// Запрос с экрана фокуса обработан: история открыта.
    func focusHistoryOpened() { navigator.wantsFocusHistory = false }

    // MARK: - Привычки

    var allowsRestDays: Bool {
        get { current.allowsRestDays }
        set { settings.update { $0.allowsRestDays = newValue } }
    }

    var skippedDaysKeepStreak: Bool {
        get { current.skippedDaysKeepStreak }
        set { settings.update { $0.skippedDaysKeepStreak = newValue } }
    }

    // MARK: - Данные

    var exportFile: ExportFile {
        let day = clock.now.formatted(.iso8601.year().month().day())
        return ExportFile(fileName: "TickFlow-\(day).json") { [tasks, lists, habits, timeEntries, clock] in
            try ExportService.makeJSON(
                tasks: tasks.tasks, lists: lists.lists, habits: habits.habits,
                timeEntries: timeEntries.entries, exportedAt: clock.now
            )
        }
    }

    func requestLoadSample() {
        isLoadSampleConfirmationPresented = true
    }

    func confirmLoadSample() {
        loadSampleData()
        toasts.show(L10n.Profile.sampleLoaded)
    }

    // MARK: - О приложении

    var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    /// Показывает знакомство заново; после него приложение открывается на вкладке «Задачи».
    func replayOnboarding() {
        navigator.selectedTab = .tasks
        settings.update { $0.hasCompletedOnboarding = false }
    }

    /// Системные настройки приложения — включить уведомления.
    var systemSettingsURL: URL? { URL(string: UIApplication.openSettingsURLString) }

    private var format: DisplayFormatter { DisplayFormatter(settings: current, clock: clock) }
}
