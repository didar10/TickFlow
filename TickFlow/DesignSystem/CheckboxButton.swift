import SwiftUI

/// Чекбокс задачи. Цвет обводки берётся из приоритета — как в TickTick.
struct CheckboxButton: View {
    let isCompleted: Bool
    let priority: Priority
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isCompleted ? Color.secondary : priority.color, lineWidth: 1.5)
                    .frame(width: 22, height: 22)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: isCompleted)
        .accessibilityLabel(isCompleted ? "Снять отметку" : "Отметить выполненной")
    }
}
