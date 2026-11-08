import SwiftUI

struct ToastView: View {
    let toast: ToastCenter.Toast
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if toast.showsSaved {
                    Label(L10n.Common.saved, systemImage: "checkmark")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#A1A1A8"))
                        .labelStyle(SavedLabelStyle())
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if toast.undo != nil {
                Button(L10n.Common.undo, action: undo)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.toastAction)
                    .buttonStyle(.plain)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 14)
        .padding(.vertical, 11)
        .background(AppColors.toastBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 15, y: 10)
        .animation(.easeOut(duration: 0.2), value: toast.showsSaved)
    }
}

private struct SavedLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(hex: "#7BD88F"))
            configuration.title
        }
    }
}
