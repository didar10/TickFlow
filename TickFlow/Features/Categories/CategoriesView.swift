import SwiftUI

/// Профиль › Категории: цвет, число открытых задач и учёт времени по умолчанию.
struct CategoriesView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var viewModel: CategoriesViewModel

    init(viewModel: CategoriesViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                LargeHeader(title: L10n.Common.categories) { EmptyView() }
                    .padding(.horizontal, -16)
                    .padding(.bottom, 10)

                VStack(spacing: 0) {
                    ForEach(viewModel.rows) { row in
                        Button { viewModel.edit(row.id) } label: {
                            CategoryRowView(row: row)
                        }
                        .buttonStyle(.plain)
                        SettingsDivider()
                    }
                    Button(action: viewModel.add) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus").font(.system(size: 16, weight: .semibold))
                            Text(L10n.Lists.newCategory)
                            Spacer()
                        }
                        .font(AppFont.body)
                        .foregroundStyle(AppColors.accent)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 50)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                SettingsFootnote(L10n.Lists.screenFootnote)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .sheet(item: $viewModel.editorRequest) { request in
            ListEditorView(viewModel: dependencies.makeListEditorViewModel(list: request.list))
        }
    }
}

private struct CategoryRowView: View {
    let row: CategoriesViewModel.Row

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(Color(hex: row.colorHex)).frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.name)
                    .font(AppFont.body)
                    .foregroundStyle(AppColors.label)
                    .lineLimit(1)
                Text(row.openTasks)
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer(minLength: 8)
            if row.tracksTime {
                Label(L10n.Lists.trackingBadge, systemImage: "timer")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.accent)
            }
            Chevron()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}
