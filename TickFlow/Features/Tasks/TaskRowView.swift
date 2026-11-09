import SwiftUI

/// Строка задачи: чекбокс, приоритет и название, под ними срок, категория и значки.
struct TaskRowView: View {
    let item: TaskRowItem
    var isCompact = false
    /// Кнопка таймера справа. `nil` — кнопки нет.
    var onTimer: (() -> Void)?
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: isCompact ? .center : .top, spacing: 12) {
            CheckCircle(
                isOn: item.isCompleted,
                tint: Color(hex: item.categoryColorHex),
                isUrgent: item.isUrgent,
                action: onToggle
            )
            .padding(.top, isCompact ? 0 : 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    if !item.priorityMarks.isEmpty {
                        Text(item.priorityMarks)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppColors.danger)
                    }
                    Text(item.title)
                        .font(AppFont.body)
                        .foregroundStyle(item.isCompleted ? AppColors.textQuaternary : AppColors.label)
                        .strikethrough(item.isCompleted)
                        .lineLimit(1)
                }

                if !isCompact {
                    meta
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let tracking = item.tracking, tracking.canStart, let onTimer {
                RowTimerButton(taskID: item.id, title: item.title, action: onTimer)
                    .frame(maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, isCompact ? 9 : 13)
        .contentShape(Rectangle())
    }

    private var meta: some View {
        FlowLayout(spacing: 8, lineSpacing: 3) {
            Text(item.meta)
                .foregroundStyle(item.isOverdue ? AppColors.danger : AppColors.textTertiary)
                .fontWeight(item.isOverdue ? .medium : .regular)

            HStack(spacing: 4) {
                Circle()
                    .fill(Color(hex: item.categoryColorHex))
                    .frame(width: 7, height: 7)
                Text(item.categoryName)
            }

            if let progress = item.subtaskProgress {
                Label(progress, systemImage: "list.bullet")
                    .labelStyle(CompactLabelStyle())
            }
            if item.hasReminder {
                Image(systemName: "bell").font(.system(size: 11))
            }
            if item.isRepeating {
                Image(systemName: "repeat").font(.system(size: 11))
            }
            if let tracking = item.tracking {
                TrackedTimeLabel(taskID: item.id, tracking: tracking)
            }
            if item.hasConflict {
                Label(L10n.Common.overlap, systemImage: "exclamationmark.triangle")
                    .labelStyle(CompactLabelStyle())
                    .foregroundStyle(AppColors.warningText)
                    .fontWeight(.medium)
            }
        }
        .font(AppFont.footnote)
        .foregroundStyle(AppColors.textTertiary)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Значок и текст вплотную, как в метаданных строки.
struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.font(.system(size: 11, weight: .semibold))
            configuration.title
        }
    }
}

/// «1 ч 10 мин / 2 ч 30 мин» в метаданных строки. Пока идёт сессия этой задачи, время растёт.
private struct TrackedTimeLabel: View {
    @Environment(FocusEngine.self) private var focus
    let taskID: UUID
    let tracking: TaskRowItem.Tracking

    var body: some View {
        let isLive = focus.isLive(taskID: taskID)
        let total = tracking.trackedMinutes + Int((focus.liveSeconds(taskID: taskID) / 60).rounded())
        let isOver = tracking.estimateMinutes.map { total > $0 } ?? false
        if total > 0 {
            Label(FocusText.tracked(total, estimate: tracking.estimateMinutes), systemImage: "timer")
                .labelStyle(CompactLabelStyle())
                .foregroundStyle(isOver ? AppColors.warningText : isLive ? AppColors.accent : AppColors.textTertiary)
                .fontWeight(isOver || isLive ? .semibold : .regular)
                .monospacedDigit()
        }
    }
}

/// Кнопка таймера в строке: ▶ запускает, во время сессии показывает живое время.
private struct RowTimerButton: View {
    @Environment(FocusEngine.self) private var focus
    let taskID: UUID
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if focus.isLive(taskID: taskID), let run = focus.run {
                Text(run.clockText(at: focus.now))
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(run.phase.isBreak ? AppColors.breakTint : AppColors.accent, in: Capsule())
                    .accessibilityLabel(L10n.Focus.openTimer)
            } else {
                Image(systemName: "play.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 32, height: 32)
                    .background(AppColors.accentSoft, in: Circle())
                    .accessibilityLabel(L10n.Focus.startTimerFor(title))
            }
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
}
