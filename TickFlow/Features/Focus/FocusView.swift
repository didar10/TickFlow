import SwiftUI

/// Полноэкранный фокус: кольцо фазы, управление, пресеты и сводка за сегодня.
struct FocusView: View {
    @State private var viewModel: FocusScreenViewModel
    @Environment(AppDependencies.self) private var dependencies
    @Environment(FocusEngine.self) private var focus

    init(viewModel: FocusScreenViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var tint: Color { viewModel.isBreak ? AppColors.breakTint : AppColors.accent }

    var body: some View {
        @Bindable var viewModel = viewModel

        GeometryReader { proxy in
            let compact = proxy.size.height < 700
            VStack(spacing: 0) {
                header
                taskPill.padding(.top, 4).padding(.horizontal, 24)

                VStack(spacing: 24) {
                    ring(size: compact ? 220 : 264, compact: compact)
                    if viewModel.showsDots { dots }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                controls.padding(.horizontal, 20).padding(.bottom, 18)
                if viewModel.showsPresets { presets.padding(.horizontal, 20).padding(.bottom, 16) }
                footer(compact: compact)
            }
        }
        .background(AppColors.surface.ignoresSafeArea())
        .sheet(isPresented: $viewModel.isTaskPickerPresented) {
            TaskPickerView(options: viewModel.taskOptions, selectedID: viewModel.task?.id, onSelect: viewModel.linkTask)
        }
        .sheet(isPresented: $viewModel.isSettingsPresented) {
            FocusSettingsView(viewModel: dependencies.makeFocusSettingsViewModel())
        }
        .overlay(alignment: .top) {
            if let banner = focus.banner {
                FocusBannerView(banner: banner, onTap: focus.dismissBanner, onDismiss: focus.dismissBanner)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: focus.banner?.id)
        .focusStopFlow(viewModel.stopFlow)
        .sensoryFeedback(.impact, trigger: viewModel.isRunning)
    }

    // MARK: - Шапка

    private var header: some View {
        HStack {
            circleButton("chevron.down", label: L10n.Common.close, action: viewModel.close)
            Spacer()
            Text(viewModel.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(AppColors.label)
            Spacer()
            circleButton("slider.horizontal.3", label: L10n.Focus.settings) { viewModel.isSettingsPresented = true }
                .opacity(viewModel.showsSettings ? 1 : 0)
                .disabled(!viewModel.showsSettings)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }

    private func circleButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColors.label)
                .frame(width: 40, height: 40)
                .background(AppColors.fillSecondary, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var taskPill: some View {
        Button { viewModel.isTaskPickerPresented = true } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.taskColorHex.map { Color(hex: $0) } ?? AppColors.chevron)
                    .frame(width: 8, height: 8)
                Text(viewModel.taskTitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(viewModel.task == nil ? AppColors.textSecondary : AppColors.label)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppColors.label)
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(AppColors.fillSecondary, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Focus.linkTask)
        .accessibilityValue(viewModel.taskTitle)
    }

    // MARK: - Кольцо

    private func ring(size: CGFloat, compact: Bool) -> some View {
        ZStack {
            Circle().stroke(AppColors.fillSecondary, lineWidth: 7)
            Circle()
                .trim(from: 0, to: viewModel.progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: viewModel.progress)
            VStack(spacing: 8) {
                Text(viewModel.phaseText.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(tint)
                Text(viewModel.timeText)
                    .font(.system(size: compact ? 54 : 64, weight: .light))
                    .monospacedDigit()
                    .foregroundStyle(AppColors.label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(viewModel.subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .combine)
    }

    private var dots: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(viewModel.dots) { dot in
                    Circle()
                        .fill(dot.isDone ? tint : .clear)
                        .overlay {
                            if !dot.isDone {
                                Circle().strokeBorder(dot.isCurrent ? tint : AppColors.disabled, lineWidth: 1.6)
                            }
                        }
                        .frame(width: 9, height: 9)
                }
            }
            .accessibilityHidden(true)
            Text(viewModel.counterText).font(.system(size: 13)).foregroundStyle(AppColors.textSecondary)
        }
    }

    // MARK: - Управление

    private var controls: some View {
        HStack(alignment: .top, spacing: 26) {
            control(symbol: "stop.fill", title: viewModel.stopTitle, size: 60, action: viewModel.stop)
                .opacity(viewModel.canStop ? 1 : 0.4)
                .disabled(!viewModel.canStop)
            VStack(spacing: 8) {
                Button(action: viewModel.togglePrimary) {
                    Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                        .frame(width: 84, height: 84)
                        .background(tint, in: Circle())
                        .shadow(color: tint.opacity(0.33), radius: 12, y: 10)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.primaryTitle)
                Text(viewModel.primaryTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.label)
                    .accessibilityHidden(true)
            }
            .frame(width: 96)
            control(symbol: "forward.end.fill", title: L10n.Focus.skipBreak, size: 60, action: viewModel.skipBreak)
                .opacity(viewModel.showsSkip ? 1 : 0)
                .disabled(!viewModel.showsSkip)
        }
    }

    private func control(symbol: String, title: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Button(action: action) {
                Image(systemName: symbol)
                    .font(.system(size: 20))
                    .foregroundStyle(AppColors.label)
                    .frame(width: size, height: size)
                    .background(AppColors.fillSecondary, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .accessibilityHidden(true)
        }
        .frame(width: 76)
    }

    private var presets: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.presets) { chip in
                Button { viewModel.selectPreset(chip.preset) } label: {
                    Text(chip.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(chip.isSelected ? AppColors.accent : AppColors.label)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(chip.isSelected ? AppColors.accentSoft : AppColors.fillSecondary, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(chip.isSelected ? .isSelected : [])
            }
        }
    }

    private func footer(compact: Bool) -> some View {
        HStack {
            Text(viewModel.todayText)
            Spacer(minLength: 8)
            if viewModel.canOpenHistory {
                Button(L10n.Focus.history, action: viewModel.openHistory)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
            }
        }
        .font(.system(size: 14))
        .foregroundStyle(AppColors.textSecondary)
        .lineLimit(1)
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, compact ? 14 : 8)
        .overlay(alignment: .top) { Rectangle().fill(AppColors.separator).frame(height: 0.5) }
    }
}

// MARK: - Мини-плеер

/// Тёмная плашка над таб-баром, пока идёт сессия и экран фокуса закрыт.
struct FocusMiniPlayer: View {
    @Environment(FocusEngine.self) private var focus

    var body: some View {
        if let run = focus.run {
            let ringColor = run.phase.isBreak ? AppColors.breakRingOnDark : AppColors.focusRingOnDark
            HStack(spacing: 12) {
                ZStack {
                    Circle().stroke(.white.opacity(0.18), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: focus.progress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: run.mode == .timer ? "timer" : run.phase.isBreak ? "cup.and.saucer.fill" : "target")
                        .font(.system(size: 12, weight: .bold))
                }
                .frame(width: 30, height: 30)
                .padding(3)

                VStack(alignment: .leading, spacing: 1) {
                    Text(FocusText.phaseWithState(run) + " · " + (focus.task?.title ?? L10n.Focus.noTask))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                    Text(run.clockText(at: focus.now))
                        .font(.system(size: 19, weight: .semibold))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: focus.togglePause) {
                    Image(systemName: run.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.16), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(run.isRunning ? L10n.Focus.pause : L10n.Focus.resume)
            }
            .foregroundStyle(.white)
            .padding(.leading, 10)
            .padding(.trailing, 8)
            .frame(height: 56)
            .background(AppColors.inverse, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 14, y: 10)
            .contentShape(Rectangle())
            .onTapGesture { focus.present() }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(L10n.Focus.openFocus)
        }
    }
}

// MARK: - Баннер

/// Уведомление о конце фазы, пока приложение открыто. Само исчезает через 5 секунд.
struct FocusBannerView: View {
    let banner: FocusEngine.Banner
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(banner.title).font(.system(size: 14, weight: .semibold))
                Text(banner.body).font(.system(size: 14))
            }
            .foregroundStyle(AppColors.label)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 15, y: 10)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .gesture(DragGesture(minimumDistance: 10).onEnded { if $0.translation.height < 0 { onDismiss() } })
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .task(id: banner.id) {
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled { onDismiss() }
        }
    }
}
