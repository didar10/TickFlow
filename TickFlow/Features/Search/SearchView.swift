import SwiftUI

struct SearchView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var viewModel: SearchViewModel

    init(viewModel: SearchViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            List {
                ForEach(viewModel.results) { task in
                    TaskRowView(task: task, showsListName: true) {
                        viewModel.toggle(task)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.editingTask = task }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(AppColors.surface)
                }
            }
            .listStyle(.plain)
            .screenBackground()
            .navigationTitle("Поиск")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.query, prompt: "Название, заметка или список")
            .overlay {
                if !viewModel.hasQuery {
                    ContentUnavailableView(
                        "Найти задачу",
                        systemImage: "magnifyingglass",
                        description: Text("Поиск идёт по названию, заметкам и названию списка.")
                    )
                } else if viewModel.results.isEmpty {
                    ContentUnavailableView.search(text: viewModel.query)
                }
            }
            .sheet(item: $viewModel.editingTask) { task in
                TaskEditorView(
                    viewModel: dependencies.makeTaskEditorViewModel(
                        task: task,
                        defaultList: task.list,
                        defaultDueDate: task.dueDate
                    )
                )
            }
        }
    }
}
