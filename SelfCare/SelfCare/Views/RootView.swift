import SwiftUI

struct RootView: View {
    @Bindable var model: SelfCareModel
    @Bindable var healthKit: HealthKitManager
    @Bindable var reminders: CheckInReminderService
    @Environment(\.scenePhase) private var scenePhase
    @State private var snackbarState: SnackbarPresentationState = .full

    var body: some View {
        NavigationStack {
            CheckInView(
                model: model,
                healthKit: healthKit,
                reminders: reminders,
                presentationState: $snackbarState
            )
        }
        .tint(SelfCareTheme.accent)
        .sheet(item: $model.editingFactor) { factor in
            NavigationStack {
                FactorEditorView(model: model, healthKit: healthKit, factor: factor)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task {
            model.refreshForCurrentDay()
            await healthKit.refreshIfPreviouslyRequested()
            applyHealthValues()
            await reminders.reconcileSchedule()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            model.refreshForCurrentDay()
            Task {
                await healthKit.refreshIfPreviouslyRequested()
                applyHealthValues()
                await reminders.reconcileSchedule()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSelfCareCheckIn)) { _ in
            snackbarState = .full
        }
        .onOpenURL { url in
            guard url.host == "check-in" || url.path == "/check-in" else { return }
            snackbarState = .full
        }
    }

    private func applyHealthValues() {
        model.updateHealthValues(
            exerciseMinutes: healthKit.exerciseMinutes,
            sleepHours: healthKit.sleepHours
        )
    }
}

#Preview {
    RootView(
        model: SelfCareModel(),
        healthKit: HealthKitManager(),
        reminders: CheckInReminderService()
    )
}
