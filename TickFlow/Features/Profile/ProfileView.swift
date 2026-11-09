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

                    SettingsGroup(L10n.Profile.organize) {
                        NavigationLink(value: ProfileRoute.categories) {
                            ValueRow(L10n.Common.categories, value: viewModel.categoryCount, showsChevron: true)
                        }
                        .buttonStyle(.plain)
                    }

                    SettingsGroup(L10n.Focus.phaseFocus) {
                        Button { viewModel.isFocusSettingsPresented = true } label: {
                            ValueRow(L10n.Focus.timerSettingsTitle, value: viewModel.focusTimerSummary, showsChevron: true)
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
                case .categories:
                    CategoriesView(viewModel: dependencies.makeCategoriesViewModel())
                }
            }
        }
        .confirmationDialog(L10n.Profile.loadSampleQuestion, isPresented: $viewModel.isLoadSampleConfirmationPresented,
                            titleVisibility: .visible) {
            Button(L10n.Profile.load, action: viewModel.confirmLoadSample)
        } message: {
            Text(L10n.Profile.loadSampleMessage)
        }
        .sheet(isPresented: $viewModel.isFocusSettingsPresented) {
            FocusSettingsView(viewModel: dependencies.makeFocusSettingsViewModel())
        }
        .task { await viewModel.refreshAuthorization() }
    }
}

private enum ProfileRoute: Hashable {
    case insights
    case categories
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
