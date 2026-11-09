import SwiftUI

/// Блок «Потрачено» в редакторе задачи: итог против оценки, живая сессия или кнопки запуска,
/// последние записи и ручное добавление.
struct TaskTimeSection: View {
    let viewModel: TaskEditorViewModel
    var onStop: () -> Void = {}
    var onAddManual: () -> Void = {}
    var onOpenEntry: (UUID) -> Void = { _ in }

    var body: some View {
        let summary = viewModel.timeSummary
        let tint = summary.isOver ? AppColors.warning : Color(hex: viewModel.categoryColorHex)

        VStack(alignment: .leading, spacing: 10) {
            Divider().overlay(AppColors.separator)

            HStack(alignment: .firstTextBaseline) {
                Text(L10n.Focus.trackedHeader.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Text(summary.summary)
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(AppColors.label)
            }

            ProgressBar(progress: summary.progress, tint: tint)

            HStack(spacing: 8) {
                Text(summary.balance)
                    .lineLimit(2)
                    .foregroundStyle(summary.isOver ? AppColors.warningText : AppColors.textSecondary)
                    .fontWeight(summary.isOver ? .semibold : .regular)
                Spacer(minLength: 4)
                Text(L10n.Focus.estimate).foregroundStyle(AppColors.textSecondary)
                StepperPill(
                    value: summary.estimateText,
                    minWidth: 64,
                    decrement: { viewModel.adjustEstimate(by: -15) },
                    increment: { viewModel.adjustEstimate(by: 15) }
                )
            }
            .font(AppFont.footnote)

            if viewModel.isLiveHere, let run = viewModel.focus?.run, let now = viewModel.focus?.now {
                LiveSessionCard(run: run, now: now, onToggle: viewModel.toggleLivePause, onStop: onStop, onOpen: viewModel.openLive)
            } else {
                HStack(spacing: 8) {
                    Button(action: viewModel.startFocus) {
                        Label(L10n.Focus.startFocus, systemImage: "target")
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .foregroundStyle(.white)
                            .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    Button(action: viewModel.startTimer) {
                        Label(L10n.Focus.startTimer, systemImage: "timer")
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .foregroundStyle(AppColors.accent)
                            .background(AppColors.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .font(.system(size: 15, weight: .semibold))
                .buttonStyle(.plain)
            }

            if !viewModel.entryRows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(viewModel.entryRows) { row in
                        Button { onOpenEntry(row.id) } label: {
                            TimeEntryRowView(row: row, tint: Color(hex: viewModel.categoryColorHex), iconSize: 28)
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(AppColors.hairline)
                    }
                }
            }

            HStack {
                Button(action: onAddManual) {
                    Label(L10n.Focus.addManually, systemImage: "plus")
                        .font(.system(size: 15, weight: .medium))
                }
                Spacer()
                if let title = viewModel.entriesToggleTitle {
                    Button(title, action: viewModel.toggleAllEntries)
                        .font(.system(size: 14))
                }
            }
            .foregroundStyle(AppColors.accent)
            .buttonStyle(.plain)
            .frame(minHeight: 36)
        }
    }
}

/// Идущая сессия задачи: фаза, время, пауза и стоп. Нажатие открывает экран фокуса.
struct LiveSessionCard: View {
    let run: FocusRun
    let now: Date
    let onToggle: () -> Void
    let onStop: () -> Void
    let onOpen: () -> Void

    var body: some View {
        let isBreak = run.phase.isBreak
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(FocusText.phaseWithState(run).uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.5)
                Text(run.clockText(at: now))
                    .font(.system(size: 24, weight: .semibold))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(isBreak ? AppColors.success : AppColors.accentPressed)

            circleButton(run.isRunning ? "pause.fill" : "play.fill",
                         label: run.isRunning ? L10n.Focus.pause : L10n.Focus.resume, action: onToggle)
            circleButton("stop.fill", label: L10n.Focus.stop, action: onStop)
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .background(isBreak ? AppColors.breakSoft : AppColors.accentSoft,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }

    private func circleButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(AppColors.label)
                .frame(width: 42, height: 42)
                .background(AppColors.surface, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Строка записи времени: значок типа, время, тип и статус, длительность.
struct TimeEntryRowView: View {
    let row: TimeEntryRow
    let tint: Color
    var iconSize: CGFloat = 32

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: row.kind.symbolName)
                .font(.system(size: iconSize * 0.45, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: iconSize, height: iconSize)
                .background(tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(row.title)
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.label)
                    .lineLimit(1)
                Text(row.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textTertiary)
            }
            Spacer(minLength: 8)
            Text(row.duration)
                .font(.system(size: 15, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(row.isCancelled ? AppColors.textQuaternary : AppColors.label)
                .strikethrough(row.isCancelled)
        }
        .frame(minHeight: 46)
        .contentShape(Rectangle())
    }
}

extension TimeEntryKind {
    var symbolName: String {
        switch self {
        case .focus: "target"
        case .timer: "timer"
        case .manual: "pencil"
        case .breakTime: "cup.and.saucer"
        }
    }
}
