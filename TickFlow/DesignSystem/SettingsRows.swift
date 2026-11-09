import SwiftUI

// Строки экранов настроек: группы, переключатели, значения. Общие для профиля,
// категорий, настроек фокуса и истории.
struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(AppFont.footnote)
                .tracking(0.3)
                .foregroundStyle(AppColors.textSecondary)
                .padding(.horizontal, 16)
            VStack(spacing: 0) { content }
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        _isOn = isOn
    }

    var body: some View {
        Toggle(title, isOn: $isOn)
            .font(AppFont.body)
            .foregroundStyle(AppColors.label)
            .tint(AppColors.accent)
            .settingsRow()
    }
}

struct PickerRow<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [(value: Value, title: String)]

    init(_ title: String, selection: Binding<Value>, options: [(value: Value, title: String)]) {
        self.title = title
        _selection = selection
        self.options = options
    }

    var body: some View {
        HStack {
            Text(title).font(AppFont.body).foregroundStyle(AppColors.label)
            Spacer(minLength: 8)
            Menu {
                Picker(title, selection: $selection) {
                    ForEach(options, id: \.value) { option in
                        Text(option.title).tag(option.value)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(options.first { $0.value == selection }?.title ?? "")
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .semibold))
                }
                .font(AppFont.body)
                .foregroundStyle(AppColors.textSecondary)
            }
        }
        .settingsRow()
    }
}

struct ValueRow: View {
    let title: String
    let value: String
    var showsChevron = false

    init(_ title: String, value: String, showsChevron: Bool = false) {
        self.title = title
        self.value = value
        self.showsChevron = showsChevron
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title).foregroundStyle(AppColors.label)
            Spacer()
            Text(value).foregroundStyle(AppColors.textSecondary)
            if showsChevron { Chevron() }
        }
        .font(AppFont.body)
        .settingsRow()
    }
}

struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppColors.chevron)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider().overlay(AppColors.separator).padding(.leading, 16)
    }
}

extension View {
    func settingsRow() -> some View {
        padding(.horizontal, 16)
            .frame(minHeight: 46)
            .contentShape(Rectangle())
    }
}

/// Пояснение под группой настроек.
struct SettingsFootnote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(AppFont.footnote)
            .foregroundStyle(AppColors.textSecondary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
    }
}
