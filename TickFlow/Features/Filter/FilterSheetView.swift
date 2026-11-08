import SwiftUI

struct FilterSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: FilterSheetViewModel

    init(viewModel: FilterSheetViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 14) {
            HStack {
                Button(L10n.Common.reset, action: viewModel.reset)
                Spacer()
                Text(L10n.Common.filter).font(AppFont.headline).foregroundStyle(AppColors.label)
                Spacer()
                Button(L10n.Common.done) { dismiss() }.fontWeight(.semibold)
            }
            .font(.system(size: 17))
            .foregroundStyle(AppColors.accent)
            .buttonStyle(.plain)
            .frame(height: 48)

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.Common.categories).font(AppFont.footnote).foregroundStyle(AppColors.textSecondary)
                FlowLayout(spacing: 8) {
                    ForEach(viewModel.categories) { option in
                        Chip(
                            title: option.name,
                            isSelected: option.isSelected,
                            dotColor: Color(hex: option.colorHex),
                            selectedColor: Color(hex: option.colorHex)
                        ) {
                            viewModel.toggleCategory(option.id)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .card()

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.Common.status).font(AppFont.footnote).foregroundStyle(AppColors.textSecondary)
                SegmentedPicker(options: viewModel.statusOptions, selection: $viewModel.status, background: AppColors.fillSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .card()

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .background(AppColors.background.ignoresSafeArea())
        .presentationDetents([.height(330)])
        .presentationDragIndicator(.visible)
    }
}

/// Раскладка «в строку с переносом» для чипов.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    /// Отступ между строками. По умолчанию равен `spacing`.
    var lineSpacing: CGFloat?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                // Элементы строки выравниваются по центру по вертикали.
                let y = bounds.minY + row.y + (row.height - size.height) / 2
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row { var indices: [Int] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            var row = rows[rows.count - 1]
            let needed = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if needed > width, !row.indices.isEmpty {
                let y = row.y + row.height + (lineSpacing ?? spacing)
                rows.append(Row(indices: [index], y: y, width: size.width, height: size.height))
                continue
            }
            row.indices.append(index)
            row.width = needed
            row.height = max(row.height, size.height)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
