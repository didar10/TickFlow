import SwiftUI

/// Строка сессии: значок вида записи в цвете категории, название, время и длительность.
struct SessionRowView: View {
    let row: SessionRowItem

    var body: some View {
        let style = row.colorHex.map { CategoryStyle(hex: $0) }
        HStack(spacing: 12) {
            Image(systemName: row.kind.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(style?.tint ?? AppColors.accent)
                .frame(width: 32, height: 32)
                .background(style?.background ?? AppColors.accentSoft, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(AppFont.body)
                    .foregroundStyle(row.isCancelled ? AppColors.textTertiary : row.hasTask ? AppColors.label : AppColors.textSecondary)
                    .strikethrough(row.isCancelled)
                    .lineLimit(1)
                Text(row.time)
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(row.duration)
                    .font(.system(size: 15, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(AppColors.label)
                if let text = row.badgeText {
                    Text(text)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(badgeColors.1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(badgeColors.0, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var badgeColors: (Color, Color) {
        switch row.badge {
        case .interrupted: (AppColors.warningSoft, AppColors.warningText)
        case .live: (AppColors.accentSoft, AppColors.accent)
        case .cancelled, nil: (AppColors.fillSecondary, AppColors.textSecondary)
        }
    }
}

/// Карточка со строками сессий и разделителями.
struct SessionRowsCard: View {
    let rows: [SessionRowItem]
    let onTap: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                Button { onTap(row.id) } label: { SessionRowView(row: row) }
                    .buttonStyle(.plain)
                if index < rows.count - 1 {
                    Divider().overlay(AppColors.separator).padding(.leading, 58)
                }
            }
        }
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
