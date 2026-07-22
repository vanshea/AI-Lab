import SwiftUI

struct RootView: View {
    @Bindable var model: SelfCareModel
    @Bindable var healthKit: HealthKitManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            CheckInView(model: model, healthKit: healthKit)
        }
        .tint(SelfCareTheme.accent)
        .sheet(item: $model.editingFactor) { factor in
            NavigationStack {
                FactorEditorView(model: model, healthKit: healthKit, factor: factor)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { !model.hasCompletedOnboarding },
                set: { isPresented in
                    if !isPresented {
                        model.completeOnboarding()
                    }
                }
            )
        ) {
            WelcomeView {
                model.completeOnboarding()
            }
            .interactiveDismissDisabled()
        }
        .task {
            model.refreshForCurrentDay()
            await healthKit.refreshIfPreviouslyRequested()
            applyHealthValues()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            model.refreshForCurrentDay()
            Task {
                await healthKit.refreshIfPreviouslyRequested()
                applyHealthValues()
            }
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
    RootView(model: SelfCareModel(), healthKit: HealthKitManager())
}
