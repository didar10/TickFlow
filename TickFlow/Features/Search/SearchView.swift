import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SearchViewModel
    @FocusState private var isFocused: Bool

    init(viewModel: SearchViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColors.textTertiary)
                    TextField("Поиск задач и дат", text: $viewModel.query)
                        .font(.system(size: 17))
                        .focused($isFocused)
                        .submitLabel(.search)
                }
                .padding(.horizontal, 10)
                .frame(height: 38)
                .background(AppColors.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button("Отмена") { dismiss() }
                    .font(.system(size: 17))
                    .foregroundStyle(AppColors.accent)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !viewModel.hasQuery {
                        Text("ПОДСКАЗКИ")
                            .font(AppFont.footnote)
                            .tracking(0.3)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.horizontal, 4)
                            .padding(.top, 10)
                            .padding(.bottom, 8)
                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.suggestions, id: \.self) { suggestion in
                                Chip(title: suggestion, unselectedBackground: AppColors.surface) {
                                    viewModel.applySuggestion(suggestion)
                                }
                            }
                        }
                    }

                    if !viewModel.results.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(viewModel.results) { row in
                                resultRow(row)
                            }
                        }
                        .card(cornerRadius: 12)
                        .padding(.top, 6)
                    }

                    if viewModel.showsNoResults {
                        VStack(spacing: 6) {
                            Text("Ничего не найдено")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(AppColors.label)
                            Text("Нет совпадений с «\(viewModel.trimmedQueryText)». Попробуйте слово покороче.")
                                .font(AppFont.subheadline)
                                .foregroundStyle(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 60)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .background(AppColors.background.ignoresSafeArea())
        .onAppear { isFocused = true }
        .taskEditor($viewModel.editorRequest)
    }

    private func resultRow(_ row: SearchViewModel.ResultRow) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: row.colorHex))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(AppFont.body)
                    .foregroundStyle(row.isCompleted ? AppColors.textQuaternary : AppColors.label)
                    .strikethrough(row.isCompleted)
                    .lineLimit(1)
                Text(row.meta)
                    .font(AppFont.footnote)
                    .foregroundStyle(row.isOverdue ? AppColors.danger : AppColors.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { viewModel.open(row.id) }
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppColors.separator).frame(height: 0.5)
        }
    }
}
