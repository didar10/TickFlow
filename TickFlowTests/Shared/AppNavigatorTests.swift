import Testing
@testable import TickFlow

@MainActor
struct AppNavigatorTests {
    @Test func startsOnTasks() {
        let navigator = AppNavigator()
        #expect(navigator.selectedTab == .tasks)
        #expect(!navigator.wantsNewTask)
        #expect(!navigator.wantsNewHabit)
    }

    @Test func openNewTaskGoesToCalendar() {
        let navigator = AppNavigator()
        navigator.openNewTask()
        #expect(navigator.selectedTab == .calendar)
        #expect(navigator.wantsNewTask)
        #expect(!navigator.wantsNewHabit)
    }

    @Test func openNewHabitGoesToHabits() {
        let navigator = AppNavigator()
        navigator.openNewHabit()
        #expect(navigator.selectedTab == .habits)
        #expect(navigator.wantsNewHabit)
        #expect(!navigator.wantsNewTask)
    }

    @Test func openSettingsGoesToProfile() {
        let navigator = AppNavigator()
        navigator.openSettings()
        #expect(navigator.selectedTab == .profile)
    }

    @Test func tabsHaveTitlesAndSymbols() {
        #expect(AppTab.allCases == [.tasks, .calendar, .habits, .profile])
        for tab in AppTab.allCases {
            #expect(!tab.title.isEmpty)
            #expect(!tab.symbolName.isEmpty)
        }
    }
}
