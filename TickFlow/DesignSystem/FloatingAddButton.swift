import SwiftUI

/// Круглая кнопка создания в правом нижнем углу экрана.
struct FloatingAddButton: View {
    var accessibilityLabel = L10n.Common.newTask
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(AppColors.accent, in: Circle())
                .shadow(color: AppColors.accent.opacity(0.35), radius: 10, y: 8)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 18)
        .padding(.bottom, 18)
        .accessibilityLabel(accessibilityLabel)
    }
}
