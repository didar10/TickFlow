import SwiftUI

/// Чип-фильтр или вариант выбора. Цветная точка — для категорий.
struct Chip: View {
    let title: String
    var isSelected = false
    var dotColor: Color?
    var selectedColor: Color = AppColors.label
    var unselectedBackground: Color = AppColors.fillSecondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let dotColor {
                    Circle()
                        .fill(isSelected && selectedColor != AppColors.label ? .white : dotColor)
                        .frame(width: 8, height: 8)
                }
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .foregroundStyle(isSelected ? Color.white : AppColors.label)
            .background(isSelected ? selectedColor : unselectedBackground, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
