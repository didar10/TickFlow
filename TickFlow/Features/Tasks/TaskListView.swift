import SwiftUI

/// Экран задач для одной подборки.
struct TaskListView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var viewModel: TaskListViewModel

    init(viewModel: TaskListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        List {
            ForEach(viewModel.groups) { group in
                Section {
                    ForEach(group.tasks) { task in
                        row(for: task)
                    }
                } header: {
                    if !group.title.isEmpty {
                        Text(group.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .textCase(nil)
                    }
                }
            }

            if !viewModel.completedTasks.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $viewModel.showsCompleted) {
                        ForEach(viewModel.completedTasks) { task in
                            row(for: task)
                        }
                    } label: {
                        Text("Завершено: \(viewModel.completedTasks.count)")
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(AppColors.surface)
                }
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.bottom, 88, for: .scrollContent)
        .screenBackground()
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if viewModel.isEmpty {
                ContentUnavailableView(
                    "Задач нет",
                    systemImage: "checkmark.circle",
                    description: Text("Добавьте первую задачу кнопкой «плюс».")
                )
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if viewModel.canAddTask {
                FloatingAddButton { viewModel.isCreatingTask = true }
            }
        }
        .sheet(isPresented: $viewModel.isCreatingTask) {
            TaskEditorView(
                viewModel: dependencies.makeTaskEditorViewModel(
                    task: nil,
                    defaultList: viewModel.currentList,
                    defaultDueDate: viewModel.filter.defaultDueDate
                )
            )
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

    // MARK: - Строки

    @ViewBuilder
    private func row(for task: TaskItem) -> some View {
        TaskRowView(task: task, showsListName: viewModel.showsListName) {
            withAnimation(.snappy) { viewModel.toggle(task) }
        }
        .contentShape(Rectangle())
        .onTapGesture { viewModel.editingTask = task }
        .listRowInsets(EdgeInsets())
        .listRowBackground(AppColors.surface)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation { viewModel.delete(task) }
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                viewModel.moveToToday(task)
            } label: {
                Label("Сегодня", systemImage: "star")
            }
            .tint(.orange)
        }
    }
}
