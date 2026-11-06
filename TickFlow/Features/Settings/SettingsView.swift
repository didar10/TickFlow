import SwiftUI

struct SettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Настройки")
                        .font(AppFont.largeTitle)
                        .tracking(-0.5)
                        .foregroundStyle(AppColors.label)
                        .padding(.horizontal, 4)

                    if viewModel.notificationsDenied {
                        Button {
                            if let url = viewModel.systemSettingsURL { openURL(url) }
                        } label: {
                            Text("Уведомления выключены. Откройте Настройки iOS › TickFlow › Уведомления, чтобы получать напоминания о задачах и привычках.")
                                .font(.system(size: 14))
                                .foregroundStyle(AppColors.dangerText)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(AppColors.dangerSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    SettingsGroup("Оформление") {
                        PickerRow("Тема", selection: $viewModel.theme,
                                  options: viewModel.themeOptions.map { ($0, $0.title) })
                    }

                    SettingsGroup("Календарь") {
                        PickerRow("Первый день недели", selection: $viewModel.firstWeekday,
                                  options: viewModel.weekdayOptions)
                        SettingsDivider()
                        PickerRow("Вид по умолчанию", selection: $viewModel.defaultCalendarMode,
                                  options: viewModel.calendarModeOptions)
                        SettingsDivider()
                        ToggleRow("24-часовой формат", isOn: $viewModel.uses24HourTime)
                        SettingsDivider()
                        PickerRow("Длительность задачи", selection: $viewModel.defaultTaskDuration,
                                  options: viewModel.durationOptions)
                        SettingsDivider()
                        HStack(spacing: 6) {
                            Text("Рабочие часы").font(AppFont.body).foregroundStyle(AppColors.label).lineLimit(1).fixedSize()
                            Spacer(minLength: 4)
                            StepperPill(value: viewModel.workdayStartLabel, minWidth: 44,
                                        decrement: { viewModel.shiftWorkdayStart(-1) },
                                        increment: { viewModel.shiftWorkdayStart(1) })
                            Text("–").foregroundStyle(AppColors.textQuaternary)
                            StepperPill(value: viewModel.workdayEndLabel, minWidth: 44,
                                        decrement: { viewModel.shiftWorkdayEnd(-1) },
                                        increment: { viewModel.shiftWorkdayEnd(1) })
                        }
                        .settingsRow()
                    }

                    SettingsGroup("Уведомления") {
                        ToggleRow("Напоминания о задачах", isOn: $viewModel.taskRemindersEnabled)
                            .disabled(viewModel.notificationsDenied)
                        SettingsDivider()
                        PickerRow("По умолчанию", selection: $viewModel.defaultReminder,
                                  options: viewModel.reminderOptions.map { ($0, $0.title) })
                        SettingsDivider()
                        ToggleRow("Напоминания о привычках", isOn: $viewModel.habitRemindersEnabled)
                            .disabled(viewModel.notificationsDenied)
                    }

                    SettingsGroup("Категории") {
                        ForEach(viewModel.categories) { category in
                            Button { viewModel.editCategory(category.id) } label: {
                                HStack(spacing: 10) {
                                    Circle().fill(Color(hex: category.colorHex)).frame(width: 10, height: 10)
                                    Text(category.name).foregroundStyle(AppColors.label)
                                    Spacer()
                                    Text(category.count).foregroundStyle(AppColors.textSecondary)
                                    Chevron()
                                }
                                .font(AppFont.body)
                                .settingsRow()
                            }
                            .buttonStyle(.plain)
                            SettingsDivider()
                        }
                        Button(action: viewModel.addCategory) {
                            HStack(spacing: 10) {
                                Image(systemName: "plus").font(.system(size: 14, weight: .semibold))
                                Text("Новая категория")
                                Spacer()
                            }
                            .font(AppFont.body)
                            .foregroundStyle(AppColors.accent)
                            .settingsRow()
                        }
                        .buttonStyle(.plain)
                    }

                    SettingsGroup("Привычки") {
                        ToggleRow("Разрешить дни отдыха", isOn: $viewModel.allowsRestDays)
                        SettingsDivider()
                        ToggleRow("Пропуски сохраняют серию", isOn: $viewModel.skippedDaysKeepStreak)
                    }

                    SettingsGroup("Данные и конфиденциальность") {
                        ShareLink(item: viewModel.exportFile,
                                  preview: SharePreview("Данные TickFlow", image: Image(systemName: "doc.text"))) {
                            ValueRow("Экспорт данных", value: "JSON", showsChevron: true)
                        }
                        .buttonStyle(.plain)
                        SettingsDivider()
                        Button(action: viewModel.requestLoadSample) {
                            ValueRow("Загрузить пример", value: "", showsChevron: true)
                        }
                        .buttonStyle(.plain)
                        SettingsDivider()
                        ValueRow("Хранение", value: "На устройстве")
                    }

                    SettingsGroup("О приложении") {
                        ValueRow("Версия", value: viewModel.version)
                        SettingsDivider()
                        Button(action: viewModel.replayOnboarding) {
                            ValueRow("Пройти знакомство заново", value: "", showsChevron: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .background(AppColors.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .sheet(item: $viewModel.listEditorRequest) { request in
            ListEditorView(viewModel: dependencies.makeListEditorViewModel(list: request.list))
        }
        .confirmationDialog("Загрузить пример данных?", isPresented: $viewModel.isLoadSampleConfirmationPresented,
                            titleVisibility: .visible) {
            Button("Загрузить", action: viewModel.confirmLoadSample)
        } message: {
            Text("Добавятся категории, задачи и привычки с историей. Ваши данные останутся.")
        }
        .task { await viewModel.refreshAuthorization() }
    }
}

// MARK: - Строки

private struct SettingsGroup<Content: View>: View {
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

private struct ToggleRow: View {
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

private struct PickerRow<Value: Hashable>: View {
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

private struct ValueRow: View {
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

private struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppColors.chevron)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider().overlay(AppColors.separator).padding(.leading, 16)
    }
}

private extension View {
    func settingsRow() -> some View {
        padding(.horizontal, 16)
            .frame(minHeight: 46)
            .contentShape(Rectangle())
    }
}
