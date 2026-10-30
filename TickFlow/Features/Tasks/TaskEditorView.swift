import SwiftUI

/// Создание и редактирование задачи.
struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TaskEditorViewModel

    init(viewModel: TaskEditorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section {
                    TextField("Название", text: $viewModel.title, axis: .vertical)
                        .font(.headline)
                    TextField("Заметки", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Срок") {
                    Toggle("Дата", isOn: $viewModel.hasDueDate.animation())
                    if viewModel.hasDueDate {
                        DatePicker(
                            viewModel.hasTime ? "Начало" : "День",
                            selection: $viewModel.dueDate,
                            displayedComponents: viewModel.hasTime ? [.date, .hourAndMinute] : [.date]
                        )
                        Toggle("Указать время", isOn: $viewModel.isTimeEnabled.animation())
                        if viewModel.hasTime {
                            DatePicker("Конец", selection: $viewModel.endTime, displayedComponents: .hourAndMinute)
                            Label(
                                "Придёт локальное уведомление",
                                systemImage: "bell"
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Picker("Список", selection: $viewModel.selectedListID) {
                        Text("Без списка").tag(UUID?.none)
                        ForEach(viewModel.lists) { list in
                            Text(list.name).tag(UUID?.some(list.id))
                        }
                    }

                    Picker("Приоритет", selection: $viewModel.priority) {
                        ForEach(Priority.allCases) { value in
                            Label(value.title, systemImage: value.symbolName)
                                .tag(value)
                        }
                    }
                }

                Section("Подзадачи") {
                    ForEach($viewModel.subtasks) { $subtask in
                        HStack(spacing: 12) {
                            Button {
                                subtask.isCompleted.toggle()
                            } label: {
                                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(subtask.isCompleted ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                            }
                            .buttonStyle(.plain)

                            TextField("Подзадача", text: $subtask.title)
                                .strikethrough(subtask.isCompleted)
                        }
                    }
                    .onDelete(perform: viewModel.removeSubtasks)

                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.tint)
                        TextField("Новая подзадача", text: $viewModel.newSubtaskTitle)
                            .onSubmit(viewModel.addSubtask)
                    }
                }

                if viewModel.isExisting {
                    Section {
                        Button(role: .destructive) {
                            viewModel.deleteTask()
                            dismiss()
                        } label: {
                            Label("Удалить задачу", systemImage: "trash")
                        }
                    }
                }
            }
            .screenBackground()
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        viewModel.save()
                        dismiss()
                    }
                    .disabled(!viewModel.canSave)
                }
            }
        }
    }
}
