import Foundation
import Observation
import SwiftUI

/// Состояние корня: выбранная вкладка, тема и тост.
@MainActor
@Observable
final class RootViewModel {
    @ObservationIgnored private let settings: any SettingsRepository
    @ObservationIgnored private let toasts: ToastCenter
    @ObservationIgnored private let navigator: AppNavigator

    init(settings: any SettingsRepository, toasts: ToastCenter, navigator: AppNavigator) {
        self.settings = settings
        self.toasts = toasts
        self.navigator = navigator
    }

    var selectedTab: AppTab {
        get { navigator.selectedTab }
        set { navigator.selectedTab = newValue }
    }

    /// Онбординг показывается, пока его не прошли (или после «Пройти знакомство заново»).
    var isOnboardingPresented: Bool {
        get { !settings.settings.hasCompletedOnboarding }
        set { }
    }

    var colorScheme: ColorScheme? {
        switch settings.settings.theme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var toast: ToastCenter.Toast? {
        toasts.current
    }

    func undoToast() {
        toasts.performUndo()
    }
}
