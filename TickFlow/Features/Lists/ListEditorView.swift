import SwiftData
import SwiftUI

struct ListEditorView: View {
    let list: TaskList?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \TaskList.sortOrder) private var lists: [TaskList]

    @State private var name = ""
    @State private var colorHex = AppPalette.listColors[0]
    @State private var symbolName = AppPalette.listSymbols[0]

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название списка", text: $name)
                }

                Section("Цвет") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AppPalette.listColors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    Circle()
                                        .stroke(Color.primary, lineWidth: colorHex == hex ? 2 : 0)
                                        .padding(-4)
                                }
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Иконка") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AppPalette.listSymbols, id: \.self) { symbol in
                            Image(systemName: symbol)
                                .font(.title3)
                                .frame(width: 40, height: 40)
                                .background {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(symbolName == symbol
                                              ? Color(hex: colorHex).opacity(0.2)
                                              : Color.clear)
                                }
                                .foregroundStyle(symbolName == symbol ? Color(hex: colorHex) : .secondary)
                                .onTapGesture { symbolName = symbol }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .screenBackground()
            .navigationTitle(list == nil ? "Новый список" : "Список")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let list {
                    name = list.name
                    colorHex = list.colorHex
                    symbolName = list.symbolName
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let list {
            list.name = trimmed
            list.colorHex = colorHex
            list.symbolName = symbolName
        } else {
            let newList = TaskList(
                name: trimmed,
                colorHex: colorHex,
                symbolName: symbolName,
                sortOrder: (lists.map(\.sortOrder).max() ?? 0) + 1
            )
            context.insert(newList)
        }

        try? context.save()
        dismiss()
    }
}
