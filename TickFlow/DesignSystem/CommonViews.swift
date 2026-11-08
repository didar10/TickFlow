import SwiftUI

/// Заголовок крупного экрана с кнопкой справа.
struct LargeHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .bottom) {
            Text(title)
                .font(AppFont.largeTitle)
                .tracking(-0.5)
                .foregroundStyle(AppColors.label)
            Spacer()
            trailing.padding(.bottom, 4)
        }
        .padding(.leading, 20)
        .padding(.trailing, 18)
        .padding(.top, 8)
    }
}

/// Пустое состояние: иконка, заголовок, текст и кнопка.
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(AppColors.accent)
                .frame(width: 56, height: 56)
                .background(AppColors.accentSoft, in: Circle())
                .padding(.bottom, 6)
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppColors.label)
            Text(message)
                .font(AppFont.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 44)
                        .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity)
    }
}

/// Плашка-предупреждение (офлайн, ошибка сохранения, уведомления выключены).
struct BannerView: View {
    enum Style { case warning, danger }

    let text: String
    var style: Style = .warning
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Text(text)
                .font(.system(size: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 14, weight: .bold))
                    .buttonStyle(.plain)
            }
        }
        .foregroundStyle(style == .warning ? AppColors.warningText : AppColors.dangerText)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            style == .warning ? AppColors.warningSoft : AppColors.dangerSoft,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

/// Счётчик «− значение +» для времени, целей и количества.
struct StepperPill: View {
    let value: String
    var minWidth: CGFloat = 70
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            stepButton("minus", action: decrement)
            Text(value)
                .font(AppFont.subheadline)
                .foregroundStyle(AppColors.label)
                .frame(minWidth: minWidth)
            stepButton("plus", action: increment)
        }
        .frame(height: 32)
        .background(AppColors.fillSecondary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 30, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
