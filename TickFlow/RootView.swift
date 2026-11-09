import SwiftUI

struct RootView: View {
    let dependencies: AppDependencies
    @State private var viewModel: RootViewModel

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = State(initialValue: dependencies.makeRootViewModel())
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        TabView(selection: $viewModel.selectedTab) {
            Tab(AppTab.tasks.title, systemImage: AppTab.tasks.symbolName, value: AppTab.tasks) {
                TasksView(viewModel: dependencies.makeTasksViewModel())
            }
            Tab(AppTab.calendar.title, systemImage: AppTab.calendar.symbolName, value: AppTab.calendar) {
                CalendarView(viewModel: dependencies.makeCalendarViewModel())
            }
            Tab(AppTab.habits.title, systemImage: AppTab.habits.symbolName, value: AppTab.habits) {
                HabitsView(viewModel: dependencies.makeHabitsViewModel())
            }
            Tab(AppTab.profile.title, systemImage: AppTab.profile.symbolName, value: AppTab.profile) {
                ProfileView(viewModel: dependencies.makeSettingsViewModel())
            }
        }
        .overlay {
            QuickTaskPanel(host: dependencies.quickEditorHost)
        }
        .tint(AppColors.accent)
        .preferredColorScheme(viewModel.colorScheme)
        .overlay(alignment: .bottom) {
            if let toast = viewModel.toast {
                ToastView(toast: toast, undo: viewModel.undoToast)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(toast.id)
            }
        }
        .animation(.easeOut(duration: 0.25), value: viewModel.toast?.id)
        .fullScreenCover(isPresented: $viewModel.isOnboardingPresented) {
            OnboardingView(viewModel: dependencies.makeOnboardingViewModel())
        }
        .task {
            await dependencies.bootstrap()
        }
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    RootView(dependencies: dependencies)
        .environment(dependencies)
        .environment(dependencies.focus)
}
