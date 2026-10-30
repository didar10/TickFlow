import SwiftData
import SwiftUI

struct TaskGroup: Identifiable {
    let id: String
    let title: String
    let tasks: [TaskItem]
}

/// Экран задач для одной подборки. Фильтрация делается в памяти:
/// для MVP это проще и надёжнее динамических предикатов @Query.
struct TaskListView: View {
    let filter: TaskFilter

    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\TaskItem.sortOrder), SortDescriptor(\TaskItem.createdAt)])
    private var allTasks: [TaskItem]
    @Query(sort: \TaskList.sortOrder) private var lists: [TaskList]

    @State private var editingTask: TaskItem?
    @State private var isCreatingTask = false
    @State private var showsCompleted = false

    var body: some View {
        List {
            ForEach(groups) { group in
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

            if !completedTasks.isEmpty, filter != .completed {
                Section {
                    DisclosureGroup(isExpanded: $showsCompleted) {
                        ForEach(completedTasks) { task in
                            row(for: task)
                        }
                    } label: {
                        Text("Завершено: \(completedTasks.count)")
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(AppColors.surface)
                }
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.bottom, 88, for: .scrollContent)
        .screenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if groups.isEmpty && completedTasks.isEmpty {
                ContentUnavailableView(
                    "Задач нет",
                    systemImage: "checkmark.circle",
                    description: Text("Добавьте первую задачу кнопкой «плюс».")
                )
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if filter != .completed {
                FloatingAddButton { isCreatingTask = true }
            }
        }
        .sheet(isPresented: $isCreatingTask) {
            TaskEditorView(
                task: nil,
                defaultList: currentList,
                defaultDueDate: filter.defaultDueDate
            )
        }
        .sheet(item: $editingTask) { task in
            TaskEditorView(task: task, defaultList: task.list, defaultDueDate: task.dueDate)
        }
    }

    // MARK: - Строки

    @ViewBuilder
    private func row(for task: TaskItem) -> some View {
        TaskRowView(task: task, showsListName: filter.isSmart) {
            toggle(task)
        }
        .contentShape(Rectangle())
        .onTapGesture { editingTask = task }
        .listRowInsets(EdgeInsets())
        .listRowBackground(AppColors.surface)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                delete(task)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                moveToToday(task)
            } label: {
                Label("Сегодня", systemImage: "star")
            }
            .tint(.orange)
        }
    }

    // MARK: - Данные

    private var currentList: TaskList? {
        guard case .list(let id) = filter else { return nil }
        return lists.first { $0.id == id }
    }

    private var title: String {
        currentList?.name ?? filter.defaultTitle
    }

    private var activeTasks: [TaskItem] {
        allTasks.filter { filter.matches($0) }
    }

    private var completedTasks: [TaskItem] {
        switch filter {
        case .completed:
            return []
        case .list(let id):
            return allTasks.filter { $0.isCompleted && $0.list?.id == id }
        case .today, .upcoming, .all:
            return allTasks.filter { task in
                guard task.isCompleted, let completedAt = task.completedAt else { return false }
                return Calendar.current.isDateInToday(completedAt)
            }
        }
    }

    private var groups: [TaskGroup] {
        let calendar = Calendar.current

        switch filter {
        case .today, .upcoming:
            let today = calendar.startOfDay(for: .now)
            var overdue: [TaskItem] = []
            var byDay: [Date: [TaskItem]] = [:]

            for task in activeTasks {
                guard let due = task.dueDate else { continue }
                let day = calendar.startOfDay(for: due)
                if day < today {
                    overdue.append(task)
                } else {
                    byDay[day, default: []].append(task)
                }
            }

            var result: [TaskGroup] = []
            if !overdue.isEmpty {
                result.append(TaskGroup(id: "overdue", title: "Просрочено", tasks: overdue))
            }
            for day in byDay.keys.sorted() {
                result.append(
                    TaskGroup(
                        id: "day-\(day.timeIntervalSince1970)",
                        title: DateFormatting.dueLabel(for: day, hasTime: false),
                        tasks: byDay[day] ?? []
                    )
                )
            }
            return result

        default:
            let tasks = activeTasks
            guard !tasks.isEmpty else { return [] }
            return [TaskGroup(id: "main", title: "", tasks: tasks)]
        }
    }

    // MARK: - Действия

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

    private func moveToToday(_ task: TaskItem) {
        let calendar = Calendar.current
        if task.hasTime, let due = task.dueDate {
            let components = calendar.dateComponents([.hour, .minute], from: due)
            task.dueDate = calendar.date(
                bySettingHour: components.hour ?? 9,
                minute: components.minute ?? 0,
                second: 0,
                of: .now
            )
        } else {
            task.dueDate = calendar.startOfDay(for: .now)
        }
        NotificationScheduler.reschedule(id: task.id, title: task.title, fireDate: task.reminderDate)
        try? context.save()
    }
}
