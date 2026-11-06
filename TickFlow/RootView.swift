import SwiftUI

struct RootView: View {
    let dependencies: AppDependencies

    var body: some View {
        TabView {
            Tab("Задачи", systemImage: "checklist") {
                HomeView(viewModel: dependencies.makeHomeViewModel())
            }
            Tab("Календарь", systemImage: "calendar") {
                CalendarView(viewModel: dependencies.makeCalendarViewModel())
            }
            Tab("Поиск", systemImage: "magnifyingglass") {
                SearchView(viewModel: dependencies.makeSearchViewModel())
            }
        }
        .task {
            await dependencies.bootstrap()
        }
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    RootView(dependencies: dependencies)
        .environment(dependencies)
}
