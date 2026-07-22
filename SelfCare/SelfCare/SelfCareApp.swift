import SwiftUI

@main
struct SelfCareApp: App {
    @State private var model = SelfCareModel()
    @State private var healthKit = HealthKitManager()

    var body: some Scene {
        WindowGroup {
            RootView(model: model, healthKit: healthKit)
                .preferredColorScheme(model.theme.colorScheme)
        }
    }
}
