import SwiftUI

/// Задачи выбранного дня под сеткой месяца.
struct AgendaList: View {
    let viewModel: CalendarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.agendaTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.label)
                Spacer()
                Text(viewModel.agendaCount)
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(.horizontal, 4)

            let rows = viewModel.agenda
            if rows.isEmpty {
                VStack(spacing: 10) {
                    Text("Ничего не запланировано")
                        .font(AppFont.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                    Button("Добавить задачу", action: viewModel.beginCreatingTask)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                        .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .card()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        AgendaRowView(row: row) {
                            viewModel.toggle(row.id)
                        } onOpen: {
                            viewModel.open(row.id)
                        }
                        if index < rows.count - 1 {
                            Divider().overlay(AppColors.separator).padding(.leading, 50)
                        }
                    }
                }
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
    }
}

private struct AgendaRowView: View {
    let row: CalendarItems.AgendaRow
    let onToggle: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            CheckCircle(isOn: row.isCompleted, tint: Color(hex: row.colorHex), isUrgent: row.isUrgent, action: onToggle)
            Button(action: onOpen) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.title)
                            .font(AppFont.body)
                            .foregroundStyle(row.isCompleted ? AppColors.textTertiary : AppColors.label)
                            .strikethrough(row.isCompleted)
                            .lineLimit(1)
                        HStack(spacing: 5) {
                            Circle().fill(Color(hex: row.colorHex)).frame(width: 6, height: 6)
                            Text(row.time)
                                .font(AppFont.footnote)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.chevron)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}
