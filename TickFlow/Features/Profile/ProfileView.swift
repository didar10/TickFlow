import SwiftUI

/// Вкладка «Профиль»: карточка пользователя (открывает аналитику) и все настройки.
struct ProfileView: View {
    @Environment(AppDependencies.self) private var dependencies
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
                    Text(L10n.Tab.profile)
                        .font(AppFont.largeTitle)
                        .tracking(-0.5)
                        .foregroundStyle(AppColors.label)
                        .padding(.horizontal, 4)

                    NavigationLink(value: ProfileRoute.insights) {
                        ProfileCard()
                    }
                    .buttonStyle(.plain)

                    if viewModel.notificationsDenied {
                        Button {
                            if let url = viewModel.systemSettingsURL { openURL(url) }
                        } label: {
                            Text(L10n.Profile.notificationsDenied)
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

                    SettingsGroup(L10n.Profile.appearance) {
                        PickerRow(L10n.Profile.theme, selection: $viewModel.theme,
                                  options: viewModel.themeOptions.map { ($0, $0.title) })
                    }

                    SettingsGroup(L10n.Tab.calendar) {
                        PickerRow(L10n.Profile.firstWeekday, selection: $viewModel.firstWeekday,
                                  options: viewModel.weekdayOptions)
                        SettingsDivider()
                        PickerRow(L10n.Profile.defaultView, selection: $viewModel.defaultCalendarMode,
                                  options: viewModel.calendarModeOptions)
                        SettingsDivider()
                        ToggleRow(L10n.Profile.use24Hour, isOn: $viewModel.uses24HourTime)
                        SettingsDivider()
                        PickerRow(L10n.Profile.taskDuration, selection: $viewModel.defaultTaskDuration,
                                  options: viewModel.durationOptions)
                        SettingsDivider()
                        HStack(spacing: 6) {
                            Text(L10n.Profile.workingHours).font(AppFont.body).foregroundStyle(AppColors.label).lineLimit(1).fixedSize()
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

                    SettingsGroup(L10n.Profile.notifications) {
                        ToggleRow(L10n.Profile.taskReminders, isOn: $viewModel.taskRemindersEnabled)
                            .disabled(viewModel.notificationsDenied)
                        SettingsDivider()
                        PickerRow(L10n.Profile.defaultReminder, selection: $viewModel.defaultReminder,
                                  options: viewModel.reminderOptions.map { ($0, $0.title) })
                        SettingsDivider()
                        ToggleRow(L10n.Profile.habitReminders, isOn: $viewModel.habitRemindersEnabled)
                            .disabled(viewModel.notificationsDenied)
                    }

                    SettingsGroup(L10n.Common.categories) {
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
                                Text(L10n.Lists.newCategory)
                                Spacer()
                            }
                            .font(AppFont.body)
                            .foregroundStyle(AppColors.accent)
                            .settingsRow()
                        }
                        .buttonStyle(.plain)
                    }

                    SettingsGroup(L10n.Tab.habits) {
                        ToggleRow(L10n.Profile.allowRestDays, isOn: $viewModel.allowsRestDays)
                        SettingsDivider()
                        ToggleRow(L10n.Profile.skipsKeepStreak, isOn: $viewModel.skippedDaysKeepStreak)
                    }

                    SettingsGroup(L10n.Profile.dataPrivacy) {
                        ShareLink(item: viewModel.exportFile,
                                  preview: SharePreview(L10n.Profile.exportPreview, image: Image(systemName: "doc.text"))) {
                            ValueRow(L10n.Profile.exportData, value: "JSON", showsChevron: true)
                        }
                        .buttonStyle(.plain)
                        SettingsDivider()
                        Button(action: viewModel.requestLoadSample) {
                            ValueRow(L10n.Common.loadSample, value: "", showsChevron: true)
                        }
                        .buttonStyle(.plain)
                        SettingsDivider()
                        ValueRow(L10n.Profile.storage, value: L10n.Profile.onDevice)
                    }

                    SettingsGroup(L10n.Profile.about) {
                        ValueRow(L10n.Profile.version, value: viewModel.version)
                        SettingsDivider()
                        Button(action: viewModel.replayOnboarding) {
                            ValueRow(L10n.Profile.replayOnboarding, value: "", showsChevron: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(L10n.Tab.profile)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .insights:
                    InsightsView(viewModel: dependencies.makeInsightsViewModel())
                }
            }
        }
        .sheet(item: $viewModel.listEditorRequest) { request in
            ListEditorView(viewModel: dependencies.makeListEditorViewModel(list: request.list))
        }
        .confirmationDialog(L10n.Profile.loadSampleQuestion, isPresented: $viewModel.isLoadSampleConfirmationPresented,
                            titleVisibility: .visible) {
            Button(L10n.Profile.load, action: viewModel.confirmLoadSample)
        } message: {
            Text(L10n.Profile.loadSampleMessage)
        }
        .task { await viewModel.refreshAuthorization() }
    }
}

private enum ProfileRoute: Hashable {
    case insights
}

/// Карточка пользователя. Учётной записи нет — данные хранятся на устройстве.
private struct ProfileCard: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 56, height: 56)
                .background(AppColors.avatar, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.Profile.myProfile)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.label)
                Text(L10n.Profile.storedOnDevice)
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.textSecondary)
                Text(L10n.Profile.viewInsights)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.accent)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
            Chevron()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
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
