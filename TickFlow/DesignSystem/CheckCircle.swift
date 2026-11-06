import SwiftUI

/// Круглый чекбокс задачи. Выполненная задача заливается цветом категории,
/// у высокого приоритета красная обводка — как в макете.
struct CheckCircle: View {
    let isOn: Bool
    var tint: Color = AppColors.accent
    var isUrgent = false
    var size: CGFloat = 22
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isOn {
                    Circle().fill(tint)
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.5, weight: .heavy))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Circle().strokeBorder(isUrgent ? AppColors.danger : AppColors.chevron, lineWidth: 1.6)
                }
            }
            .frame(width: size, height: size)
            .padding(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(-6)
        .animation(.snappy(duration: 0.2), value: isOn)
        .accessibilityLabel(isOn ? "Снять отметку" : "Отметить выполненной")
    }
}
