import SwiftData
import SwiftUI

struct CalendarView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\TaskItem.dueDate), SortDescriptor(\TaskItem.sortOrder)])
    private var allTasks: [TaskItem]
    @Query(sort: \TaskList.sortOrder) private var lists: [TaskList]

    @AppStorage("calendarMode") private var mode = CalendarMode.month
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var displayedMonth = Calendar.current.startOfDay(for: .now)
    @State private var editingTask: TaskItem?
    @State private var newTask: NewTask?

    private let calendar = Calendar.current

    /// Параметры создаваемой задачи: день из календаря или время из таймлайна.
    private struct NewTask: Identifiable {
        let id = UUID()
        let date: Date
        let hasTime: Bool
    }

    var body: some View {
        NavigationStack {
            content
                .background(AppColors.background.ignoresSafeArea())
                .overlay(alignment: .bottomTrailing) {
                    FloatingAddButton {
                        newTask = NewTask(date: selectedDate, hasTime: false)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .sheet(item: $newTask) { draft in
                    TaskEditorView(
                        task: nil,
                        defaultList: lists.first,
                        defaultDueDate: draft.date,
                        defaultHasTime: draft.hasTime
                    )
                }
                .sheet(item: $editingTask) { task in
                    TaskEditorView(task: task, defaultList: task.list, defaultDueDate: task.dueDate)
                }
                .onChange(of: selectedDate) { _, date in
                    if !calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month) {
                        displayedMonth = date
                    }
                }
                .onChange(of: mode) {
                    displayedMonth = selectedDate
                }
        }
    }

    // MARK: - Содержимое

    @ViewBuilder
    private var content: some View {
        if mode == .month {
            VStack(spacing: 0) {
                MonthGrid(
                    month: displayedMonth,
                    selectedDate: $selectedDate,
                    taskCounts: taskCounts
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
                    tasks: tasksForSelectedDay,
                    onSelect: { editingTask = $0 },
                    onToggle: toggle,
                    onDelete: delete
                )
            }
        } else {
            TimeGridView(
                days: visibleDays,
                tasks: allTasks,
                onSelect: { editingTask = $0 },
                onToggle: toggle,
                onDelete: delete,
                onCreate: { newTask = NewTask(date: $0, hasTime: true) },
                onMove: move,
                onResize: resize,
                onShift: shift
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Picker("Вид", selection: $mode) {
                    ForEach(CalendarMode.allCases) { value in
                        Label(value.title, systemImage: value.symbolName)
                            .tag(value)
                    }
                }
                .pickerStyle(.inline)

                Button("Сегодня", systemImage: "smallcircle.filled.circle") {
                    withAnimation(.snappy) {
                        selectedDate = calendar.startOfDay(for: .now)
                        displayedMonth = selectedDate
                    }
                }
            } label: {
                Image(systemName: mode.symbolName)
            }
            .accessibilityLabel("Вид календаря")
        }

        ToolbarItem(placement: .principal) {
            Text(DateFormatting.monthTitle(for: displayedMonth))
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

    // MARK: - Данные

    private var visibleDays: [Date] {
        let first = mode == .week
            ? calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            : selectedDate
        return (0..<mode.dayCount).compactMap {
            calendar.date(byAdding: .day, value: $0, to: first)
        }
    }

    private var taskCounts: [Date: Int] {
        var result: [Date: Int] = [:]
        for task in allTasks where !task.isCompleted {
            guard let due = task.dueDate else { continue }
            result[calendar.startOfDay(for: due), default: 0] += 1
        }
        return result
    }

    /// Сначала задачи на весь день, затем по времени.
    private var tasksForSelectedDay: [TaskItem] {
        let tasks = allTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return calendar.isDate(due, inSameDayAs: selectedDate)
        }
        return tasks.filter { !$0.hasTime } + tasks.filter(\.hasTime)
    }

    // MARK: - Действия

    private func shift(by value: Int) {
        withAnimation(.snappy) {
            if mode == .month {
                displayedMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
            } else {
                selectedDate = calendar.date(byAdding: .day, value: value * mode.dayCount, to: selectedDate) ?? selectedDate
                displayedMonth = selectedDate
            }
        }
    }

    private func move(_ task: TaskItem, to start: Date) {
        withAnimation(.snappy) {
            task.dueDate = start
            task.hasTime = true
        }
        NotificationScheduler.reschedule(id: task.id, title: task.title, fireDate: task.reminderDate)
        try? context.save()
    }

    private func resize(_ task: TaskItem, to minutes: Int) {
        withAnimation(.snappy) {
            task.durationMinutes = minutes
        }
        try? context.save()
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
}

#Preview {
    CalendarView()
        .modelContainer(for: [TaskList.self, TaskItem.self, Subtask.self], inMemory: true)
}
