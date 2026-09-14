import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            Tab("Задачи", systemImage: "checklist") {
                HomeView()
            }
            Tab("Календарь", systemImage: "calendar") {
                CalendarView()
            }
            Tab("Поиск", systemImage: "magnifyingglass") {
                SearchView()
            }
        }
        .task {
            SeedService.seedIfNeeded(context: context)
            await NotificationScheduler.requestAuthorization()
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [TaskList.self, TaskItem.self, Subtask.self], inMemory: true)
}
