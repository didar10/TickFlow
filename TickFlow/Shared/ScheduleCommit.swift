import Foundation

/// К какой части серии применить изменение срока повторяющейся задачи.
enum RecurringScope {
    case thisOccurrence
    case thisAndFollowing
}

/// Сохранение правки задачи с учётом серии. Общее для редактора и перетаскивания в календаре.
@MainActor
enum ScheduleCommit {

    /// Сохраняет `draft` в `task`. Для `thisOccurrence` серия продолжается по старому расписанию
    /// отдельной задачей, а эта становится разовой.
    /// - Returns: действие «Отменить».
    static func commit(
        _ draft: TaskDraft,
        to task: TaskItem,
        scope: RecurringScope?,
        repository: any TaskRepository
    ) -> () -> Void {
        let snapshot = TaskSnapshot(task)
        let original = snapshot.draft
        var draft = draft

        var continuation: TaskItem?
        if scope == .thisOccurrence, let due = original.dueDate, let nextDue = original.repeatRule.nextDate(after: due) {
            var series = original
            series.dueDate = nextDue
            if let end = original.endDay {
                series.endDay = end.addingTimeInterval(nextDue.timeIntervalSince(due))
            }
            series.isCompleted = false
            series.subtasks = series.subtasks.map { SubtaskDraft(id: UUID(), title: $0.title, isCompleted: false) }
            continuation = repository.save(series, to: nil)
            draft.repeatRule = .never
        }

        repository.save(draft, to: task)
        return {
            if let continuation { repository.delete(continuation) }
            repository.restore(snapshot)
        }
    }

    /// Текст для диалога выбора части серии.
    static func recurringMessage(title: String, rule: RepeatRule) -> String {
        L10n.Schedule.recurringQuestion(title, rule.title.lowercased())
    }

    /// Подсказка о соседних задачах: «Встык с «…»» или «Перерыв всего N мин».
    static func gapNote(start: Date, end: Date, excluding id: UUID, in tasks: [TaskItem], calendar: Calendar) -> String {
        var note = ""
        for other in tasks where other.id != id && !other.isCompleted && other.hasTime && !other.isMultiDay(calendar: calendar) {
            guard let otherStart = other.dueDate, let otherEnd = other.endDate,
                  calendar.isDate(otherStart, inSameDayAs: start) else { continue }
            let after = Int(otherStart.timeIntervalSince(end) / 60)
            let before = Int(start.timeIntervalSince(otherEnd) / 60)
            for gap in [after, before] where gap >= 0 && gap < 10 {
                note = " · " + (gap == 0 ? L10n.Schedule.backToBack(other.title) : L10n.Schedule.shortBreak(gap))
            }
        }
        return note
    }
}
