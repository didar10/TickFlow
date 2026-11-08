import Foundation

/// Действия над задачей с тостом и отменой. Общие для экранов, где задачу можно отметить из списка.
@MainActor
struct TaskActions {
    let tasks: any TaskRepository
    let toasts: ToastCenter

    /// Отмечает или снимает отметку. При выполнении — тост «Выполнено» с отменой,
    /// которая убирает и созданное следующее вхождение повторяющейся задачи.
    func toggleCompleted(_ task: TaskItem) {
        let snapshot = TaskSnapshot(task)
        let completing = !task.isCompleted
        let next = tasks.setCompleted(task, completing)
        guard completing else { return }
        toasts.show(L10n.Tasks.completedToast(task.title)) { [tasks] in
            if let next { tasks.delete(next) }
            tasks.restore(snapshot)
        }
    }

    func delete(_ task: TaskItem) {
        let snapshot = TaskSnapshot(task)
        tasks.delete(task)
        toasts.show(L10n.Tasks.deleted) { [tasks] in
            tasks.restore(snapshot)
        }
    }
}
