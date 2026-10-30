import SwiftUI

struct CalendarView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var viewModel: CalendarViewModel

    init(viewModel: CalendarViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            content
                .background(AppColors.background.ignoresSafeArea())
                .overlay(alignment: .bottomTrailing) {
                    FloatingAddButton { viewModel.beginCreatingTask() }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .sheet(item: $viewModel.newTask) { request in
                    TaskEditorView(
                        viewModel: dependencies.makeTaskEditorViewModel(
                            task: nil,
                            defaultList: viewModel.defaultList,
                            defaultDueDate: request.date,
                            defaultHasTime: request.hasTime
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
    }

    // MARK: - Содержимое

    @ViewBuilder
    private var content: some View {
        @Bindable var viewModel = viewModel

        if viewModel.mode == .month {
            VStack(spacing: 0) {
                MonthGrid(
                    month: viewModel.displayedMonth,
                    days: viewModel.monthDays,
                    weekdaySymbols: viewModel.weekdaySymbols,
                    selectedDate: $viewModel.selectedDate,
                    taskCounts: viewModel.taskCounts
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 30).onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        shift(by: value.translation.width < 0 ? 1 : -1)
                    }
                )

                AgendaList(
                    tasks: viewModel.tasksForSelectedDay,
                    onSelect: { viewModel.editingTask = $0 },
                    onToggle: { task in withAnimation(.snappy) { viewModel.toggle(task) } },
                    onDelete: { task in withAnimation { viewModel.delete(task) } }
                )
            }
        } else {
            TimeGridView(viewModel: viewModel)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        @Bindable var viewModel = viewModel

        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Picker("Вид", selection: $viewModel.mode) {
                    ForEach(CalendarMode.allCases) { value in
                        Label(value.title, systemImage: value.symbolName)
                            .tag(value)
                    }
                }
                .pickerStyle(.inline)

                Button("Сегодня", systemImage: "smallcircle.filled.circle") {
                    withAnimation(.snappy) { viewModel.goToToday() }
                }
            } label: {
                Image(systemName: viewModel.mode.symbolName)
            }
            .accessibilityLabel("Вид календаря")
        }

        ToolbarItem(placement: .principal) {
            Text(viewModel.title)
                .font(.headline)
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                shift(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Назад")

            Button {
                shift(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("Вперёд")
        }
    }

    private func shift(by value: Int) {
        withAnimation(.snappy) { viewModel.shift(by: value) }
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    CalendarView(viewModel: dependencies.makeCalendarViewModel())
        .environment(dependencies)
}
