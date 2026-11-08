import SwiftUI

struct ListEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ListEditorViewModel

    init(viewModel: ListEditorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        let tint = Color(hex: viewModel.colorHex)

        VStack(spacing: 0) {
            HStack {
                Button(L10n.Common.cancel) { dismiss() }
                Spacer()
                Text(viewModel.title).font(AppFont.headline).foregroundStyle(AppColors.label)
                Spacer()
                Button(viewModel.saveTitle, action: viewModel.save)
                    .fontWeight(.semibold)
                    .foregroundStyle(viewModel.canSave ? AppColors.accent : AppColors.chevron)
                    .disabled(!viewModel.canSave)
            }
            .font(.system(size: 17))
            .foregroundStyle(AppColors.accent)
            .buttonStyle(.plain)
            .frame(height: 48)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: viewModel.symbolName)
                            .font(.system(size: 19))
                            .foregroundStyle(tint)
                            .frame(width: 42, height: 42)
                            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        TextField(L10n.Lists.namePlaceholder, text: $viewModel.name)
                            .font(.system(size: 20, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.Lists.color).font(AppFont.footnote).foregroundStyle(AppColors.textSecondary)
                        HStack(spacing: 14) {
                            ForEach(viewModel.colors, id: \.self) { hex in
                                Button { viewModel.selectColor(hex) } label: {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 28, height: 28)
                                        .padding(3)
                                        .overlay(Circle().stroke(hex == viewModel.colorHex ? Color(hex: hex) : .clear, lineWidth: 2))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Divider().overlay(AppColors.separator).padding(.vertical, 2)
                        Text(L10n.Lists.icon).font(AppFont.footnote).foregroundStyle(AppColors.textSecondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                            ForEach(viewModel.symbols, id: \.self) { symbol in
                                let isSelected = symbol == viewModel.symbolName
                                Button { viewModel.selectSymbol(symbol) } label: {
                                    Image(systemName: symbol)
                                        .font(.system(size: 18))
                                        .foregroundStyle(isSelected ? tint : AppColors.textTertiary)
                                        .frame(width: 40, height: 40)
                                        .background(isSelected ? tint.opacity(0.12) : .clear,
                                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if viewModel.canDelete {
                        Button(L10n.Lists.deleteCategory, role: .destructive, action: viewModel.requestDelete)
                            .font(.system(size: 17))
                            .foregroundStyle(AppColors.danger)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .confirmationDialog(L10n.Common.deleteNamed(viewModel.name), isPresented: $viewModel.isDeleteConfirmationPresented,
                            titleVisibility: .visible) {
            Button(L10n.Common.delete, role: .destructive, action: viewModel.confirmDelete)
        } message: {
            Text(viewModel.deleteMessage)
        }
        .onChange(of: viewModel.isFinished) { _, finished in
            if finished { dismiss() }
        }
    }
}
