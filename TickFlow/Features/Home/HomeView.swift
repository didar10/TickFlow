import SwiftUI

/// Корневой экран: смарт-подборки сверху, пользовательские списки снизу.
struct HomeView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            List {
                Section {
                    ForEach(viewModel.smartFilters, id: \.self) { filter in
                        NavigationLink(value: filter) {
                            Label(filter.defaultTitle, systemImage: filter.symbolName)
                                .badge(viewModel.count(for: filter))
                        }
                        .listRowBackground(AppColors.surface)
                    }
                }

                Section("Списки") {
                    ForEach(viewModel.lists) { list in
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
                                viewModel.delete(list)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }

                            Button {
                                viewModel.listBeingEdited = list
                            } label: {
                                Label("Изменить", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }

                    Button {
                        viewModel.isCreatingList = true
                    } label: {
                        Label("Новый список", systemImage: "plus")
                    }
                    .listRowBackground(AppColors.surface)
                }
            }
            .screenBackground()
            .navigationTitle("TickFlow")
            .navigationDestination(for: TaskFilter.self) { filter in
                TaskListView(viewModel: dependencies.makeTaskListViewModel(filter: filter))
            }
            .sheet(isPresented: $viewModel.isCreatingList) {
                ListEditorView(viewModel: dependencies.makeListEditorViewModel(list: nil))
            }
            .sheet(item: $viewModel.listBeingEdited) { list in
                ListEditorView(viewModel: dependencies.makeListEditorViewModel(list: list))
            }
        }
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    HomeView(viewModel: dependencies.makeHomeViewModel())
        .environment(dependencies)
}
