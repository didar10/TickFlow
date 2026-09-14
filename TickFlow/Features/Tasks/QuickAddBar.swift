import SwiftUI

/// Строка быстрого добавления внизу экрана.
struct QuickAddBar: View {
    let onSubmit: (String) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(.tint)

            TextField("Добавить задачу", text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit(submit)

            if !text.isEmpty {
                Button {
                    submit()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        // Liquid Glass: доступно с iOS 26, поэтому без фолбэков.
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func submit() {
        let value = text
        text = ""
        onSubmit(value)
        isFocused = false
    }
}
