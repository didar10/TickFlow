import SwiftData
import SwiftUI

struct CalendarView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\TaskItem.dueDate), SortDescriptor(\TaskItem.sortOrder)])
    private var allTasks: [TaskItem]
    @Query(sort: \TaskList.sortOrder) private var lists: [TaskList]

    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var displayedMonth = Calendar.current.startOfDay(for: .now)
    @State private var editingTask: TaskItem?
    @State private var isCreatingTask = false

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                MonthGrid(
                    month: displayedMonth,
                    selectedDate: $selectedDate,
                    taskCounts: taskCounts
                )
                .padding(.horizontal, 12)

                Divider()
                    .padding(.top, 8)

                dayList
            }
            .navigationTitle("Календарь")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Сегодня") {
                        withAnimation {
                            selectedDate = calendar.startOfDay(for: .now)
                            displayedMonth = selectedDate
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCreatingTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Новая задача на выбранный день")
                }
            }
            .sheet(isPresented: $isCreatingTask) {
                TaskEditorView(
                    task: nil,
                    defaultList: lists.first,
                    defaultDueDate: selectedDate
                )
            }
            .sheet(item: $editingTask) { task in
                TaskEditorView(task: task, defaultList: task.list, defaultDueDate: task.dueDate)
            }
        }
    }

    // MARK: - Заголовок

    private var header: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(DateFormatting.monthTitle(for: displayedMonth))
                .font(.headline)

            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
        }
    }

    // MARK: - Задачи выбранного дня

    private var dayList: some View {
        List {
            Section {
                if tasksForSelectedDay.isEmpty {
                    Text("На этот день задач нет")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tasksForSelectedDay) { task in
                        TaskRowView(task: task, showsListName: true) {
                            toggle(task)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editingTask = task }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(task)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                Text(DateFormatting.dueLabel(for: selectedDate, hasTime: false))
            }
        }
        .listStyle(.plain)
        .safeAreaInset(edge: .bottom) {
            QuickAddBar { title in
                createTask(title: title)
            }
        }
    }

    // MARK: - Данные

    private var taskCounts: [Date: Int] {
        var result: [Date: Int] = [:]
        for task in allTasks where !task.isCompleted {
            guard let due = task.dueDate else { continue }
            result[calendar.startOfDay(for: due), default: 0] += 1
        }
        return result
    }

    private var tasksForSelectedDay: [TaskItem] {
        allTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return calendar.isDate(due, inSameDayAs: selectedDate)
        }
    }

    // MARK: - Действия

    private func shiftMonth(by value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        withAnimation(.snappy) {
            displayedMonth = next
        }
    }

    private func toggle(_ task: TaskItem) {
        withAnimation(.snappy) {
            task.setCompleted(!task.isCompleted)
        }
        try? context.save()
    }

    private func delete(_ task: TaskItem) {
        NotificationScheduler.cancel(taskID: task.id)
        withAnimation {
            context.delete(task)
        }
        try? context.save()
    }

    private func createTask(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let task = TaskItem(
            title: trimmed,
            dueDate: selectedDate,
            list: lists.first,
            sortOrder: (allTasks.map(\.sortOrder).max() ?? 0) + 1
        )
        context.insert(task)
        try? context.save()
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: [TaskList.self, TaskItem.self, Subtask.self], inMemory: true)
}
