import SwiftData
import SwiftUI

struct SearchView: View {
    @Environment(\.modelContext) private var context

    // Bool не Comparable, поэтому SortDescriptor по isCompleted не создать —
    // сортируем по дате в запросе, а незавершённые поднимаем наверх в `results`.
    @Query(sort: \TaskItem.createdAt, order: .reverse)
    private var allTasks: [TaskItem]

    @State private var query = ""
    @State private var editingTask: TaskItem?

    var body: some View {
        NavigationStack {
            List {
                ForEach(results) { task in
                    TaskRowView(task: task, showsListName: true) {
                        task.setCompleted(!task.isCompleted)
                        try? context.save()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editingTask = task }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Поиск")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Название, заметка или список")
            .overlay {
                if query.isEmpty {
                    ContentUnavailableView(
                        "Найти задачу",
                        systemImage: "magnifyingglass",
                        description: Text("Поиск идёт по названию, заметкам и названию списка.")
                    )
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .sheet(item: $editingTask) { task in
                TaskEditorView(task: task, defaultList: task.list, defaultDueDate: task.dueDate)
            }
        }
    }

    private var results: [TaskItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let matches = allTasks.filter { task in
            task.title.localizedStandardContains(trimmed)
                || task.notes.localizedStandardContains(trimmed)
                || (task.list?.name.localizedStandardContains(trimmed) ?? false)
        }
        return matches.filter { !$0.isCompleted } + matches.filter(\.isCompleted)
    }
}
