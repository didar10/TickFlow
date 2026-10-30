import SwiftData
import SwiftUI

/// Корневой экран: смарт-подборки сверху, пользовательские списки снизу.
struct HomeView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \TaskList.sortOrder) private var lists: [TaskList]
    @Query private var allTasks: [TaskItem]

    @State private var isCreatingList = false
    @State private var listBeingEdited: TaskList?

    private let smartFilters: [TaskFilter] = [.today, .upcoming, .all, .completed]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(smartFilters, id: \.self) { filter in
                        NavigationLink(value: filter) {
                            Label(filter.defaultTitle, systemImage: filter.symbolName)
                                .badge(count(for: filter))
                        }
                        .listRowBackground(AppColors.surface)
                    }
                }

                Section("Списки") {
                    ForEach(lists) { list in
                        NavigationLink(value: TaskFilter.list(list.id)) {
                            Label {
                                Text(list.name)
                            } icon: {
                                Image(systemName: list.symbolName)
                                    .foregroundStyle(Color(hex: list.colorHex))
                            }
                            .badge(list.activeCount)
                        }
                        .listRowBackground(AppColors.surface)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(list)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }

                            Button {
                                listBeingEdited = list
                            } label: {
                                Label("Изменить", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }

                    Button {
                        isCreatingList = true
                    } label: {
                        Label("Новый список", systemImage: "plus")
                    }
                    .listRowBackground(AppColors.surface)
                }
            }
            .screenBackground()
            .navigationTitle("TickFlow")
            .navigationDestination(for: TaskFilter.self) { filter in
                TaskListView(filter: filter)
            }
            .sheet(isPresented: $isCreatingList) {
                ListEditorView(list: nil)
            }
            .sheet(item: $listBeingEdited) { list in
                ListEditorView(list: list)
            }
        }
    }

    private func count(for filter: TaskFilter) -> Int {
        guard filter != .completed else { return 0 }
        return allTasks.filter { filter.matches($0) }.count
    }

    private func delete(_ list: TaskList) {
        list.tasks.forEach { NotificationScheduler.cancel(taskID: $0.id) }
        context.delete(list)
        try? context.save()
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [TaskList.self, TaskItem.self, Subtask.self], inMemory: true)
}
