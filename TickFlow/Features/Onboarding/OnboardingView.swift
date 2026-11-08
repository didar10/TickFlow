import SwiftUI

struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel

    init(viewModel: OnboardingViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            .defaultScrollAnchor(.center)
            .id(viewModel.stepIndex)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .opacity))
            buttons
        }
        .background(AppColors.surface.ignoresSafeArea())
        .animation(.snappy(duration: 0.3), value: viewModel.stepIndex)
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<viewModel.stepCount, id: \.self) { index in
                    Capsule()
                        .fill(index <= viewModel.stepIndex ? AppColors.accent : AppColors.outline)
                        .frame(width: index == viewModel.stepIndex ? 18 : 6, height: 6)
                }
            }
            Spacer()
            if viewModel.canSkip {
                Button(L10n.Onboarding.skip, action: viewModel.skip)
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.textTertiary)
                    .buttonStyle(.plain)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.step {
        case .welcome: WelcomeStep()
        case .features: FeaturesStep(features: viewModel.features)
        case .personalize: PersonalizeStep(viewModel: viewModel)
        case .reminders: RemindersStep()
        case .done: DoneStep(summary: viewModel.summary)
        }
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            Button {
                Task { await viewModel.primary() }
            } label: {
                Text(viewModel.primaryTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isRequestingPermission)

            if let secondary = viewModel.secondaryTitle {
                Button(secondary, action: viewModel.secondary)
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.accent)
                    .frame(height: 44)
                    .buttonStyle(.plain)
            }
            if viewModel.showsSampleButton {
                Button(L10n.Common.loadSampleData, action: viewModel.loadSample)
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.textTertiary)
                    .frame(height: 32)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}

// MARK: - Шаги

private struct StepTitle: View {
    let title: String
    var subtitle: String?
    var size: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: size, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(AppColors.label)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct WelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(spacing: 8) {
                previewCard(L10n.Onboarding.previewStandup, hex: "#5B5BD6", width: 0.62, alignment: .leading)
                previewCard(L10n.Onboarding.previewLunch, hex: "#2A9792", width: 0.58, alignment: .trailing)
                HStack {
                    Text(L10n.Habits.suggestionMeditation)
                    Spacer()
                    Text(L10n.Onboarding.previewStreak)
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CategoryStyle(hex: "#399E62").foreground)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(CategoryStyle(hex: "#399E62").background, in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 40)
            }
            .padding(.horizontal, 8)

            StepTitle(title: L10n.Onboarding.welcomeTitle,
                      subtitle: L10n.Onboarding.welcomeMessage,
                      size: 34)
        }
        .padding(.top, 40)
    }

    private func previewCard(_ text: String, hex: String, width: CGFloat, alignment: Alignment) -> some View {
        let style = CategoryStyle(hex: hex)
        return GeometryReader { proxy in
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(style.foreground)
                .padding(.horizontal, 12)
                .frame(width: proxy.size.width * width, height: 40, alignment: .leading)
                .background(style.background, in: RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: .infinity, alignment: alignment)
        }
        .frame(height: 40)
    }
}

private struct FeaturesStep: View {
    let features: [OnboardingViewModel.Feature]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            StepTitle(title: L10n.Onboarding.featuresTitle)
            ForEach(features) { feature in
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: feature.symbol)
                        .font(.system(size: 21))
                        .foregroundStyle(AppColors.accent)
                        .frame(width: 44, height: 44)
                        .background(AppColors.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(feature.title)
                            .font(AppFont.headline)
                            .foregroundStyle(AppColors.label)
                        Text(feature.text)
                            .font(AppFont.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.top, 40)
    }
}

private struct PersonalizeStep: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(alignment: .leading, spacing: 22) {
            StepTitle(title: L10n.Onboarding.personalizeEyebrow, subtitle: L10n.Onboarding.personalizeHint)

            section(L10n.Onboarding.planStyleQuestion) {
                FlowLayout(spacing: 8) {
                    ForEach(OnboardingViewModel.PlanStyle.allCases) { style in
                        Chip(title: style.title, isSelected: viewModel.planStyle == style,
                             selectedColor: AppColors.accent) { viewModel.selectPlanStyle(style) }
                    }
                }
            }

            section(L10n.Onboarding.weekStarts) {
                SegmentedPicker(options: viewModel.weekdayOptions, selection: $viewModel.firstWeekday,
                                background: AppColors.fillSecondary)
            }

            HStack(spacing: 6) {
                Text(L10n.Profile.workingHours).font(.system(size: 15, weight: .semibold)).foregroundStyle(AppColors.label)
                    .lineLimit(1).fixedSize()
                Spacer(minLength: 4)
                StepperPill(value: viewModel.workdayStartLabel, minWidth: 44,
                            decrement: { viewModel.shiftStart(-1) }, increment: { viewModel.shiftStart(1) })
                Text("–").foregroundStyle(AppColors.textQuaternary)
                StepperPill(value: viewModel.workdayEndLabel, minWidth: 44,
                            decrement: { viewModel.shiftEnd(-1) }, increment: { viewModel.shiftEnd(1) })
            }

            section(L10n.Onboarding.habitGoals) {
                FlowLayout(spacing: 8) {
                    ForEach(OnboardingViewModel.goals) { goal in
                        Chip(title: goal.title, isSelected: viewModel.isGoalSelected(goal),
                             selectedColor: AppColors.accent) { viewModel.toggleGoal(goal) }
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(AppColors.label)
            content()
        }
    }
}

private struct RemindersStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 8) {
                notification(time: "10:50", text: L10n.Onboarding.reminderPreviewTask)
                notification(time: "21:30", text: L10n.Onboarding.reminderPreviewHabit)
            }
            .padding(14)
            .background(AppColors.fillSecondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            StepTitle(title: L10n.Onboarding.remindersTitle,
                      subtitle: L10n.Onboarding.remindersMessage)
        }
        .padding(.top, 40)
    }

    private func notification(time: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("TickFlow").fontWeight(.semibold).foregroundStyle(AppColors.label)
                    Spacer()
                    Text(time).foregroundStyle(AppColors.textTertiary)
                }
                .font(.system(size: 13))
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.label)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppColors.surface.opacity(0.95), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct DoneStep: View {
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "checkmark")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 64, height: 64)
                .background(AppColors.accentSoft, in: Circle())
            StepTitle(title: L10n.Onboarding.allSet, subtitle: summary)
        }
        .padding(.top, 60)
    }
}
