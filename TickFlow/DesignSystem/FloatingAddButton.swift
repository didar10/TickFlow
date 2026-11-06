import SwiftUI

/// Круглая кнопка создания задачи в правом нижнем углу экрана.
struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .padding(.trailing, 20)
        .padding(.bottom, 12)
        .accessibilityLabel("Новая задача")
    }
}
