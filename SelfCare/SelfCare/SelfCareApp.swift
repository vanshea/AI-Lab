import SwiftUI

@main
struct SelfCareApp: App {
    @State private var model = SelfCareModel()
    @State private var healthKit = HealthKitManager()
    @State private var reminders = CheckInReminderService()

    var body: some Scene {
        WindowGroup {
            RootView(model: model, healthKit: healthKit, reminders: reminders)
                .preferredColorScheme(model.theme.colorScheme)
        }
    }
}
