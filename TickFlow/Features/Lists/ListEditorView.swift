import SwiftUI

struct ListEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ListEditorViewModel

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    init(viewModel: ListEditorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section {
                    TextField("Название списка", text: $viewModel.name)
                }

                Section("Цвет") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AppPalette.listColors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    Circle()
                                        .stroke(Color.primary, lineWidth: viewModel.colorHex == hex ? 2 : 0)
                                        .padding(-4)
                                }
                                .onTapGesture { viewModel.colorHex = hex }
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
                                        .fill(viewModel.symbolName == symbol
                                              ? Color(hex: viewModel.colorHex).opacity(0.2)
                                              : Color.clear)
                                }
                                .foregroundStyle(viewModel.symbolName == symbol ? Color(hex: viewModel.colorHex) : .secondary)
                                .onTapGesture { viewModel.symbolName = symbol }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .screenBackground()
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        viewModel.save()
                        dismiss()
                    }
                    .disabled(!viewModel.canSave)
                }
            }
        }
    }
}
