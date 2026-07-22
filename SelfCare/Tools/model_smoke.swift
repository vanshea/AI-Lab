import Foundation

@main
@MainActor
struct ModelSmoke {
    static func main() {
        precondition(SelfCareModel.moodLabel(for: 0) == "Low")
        precondition(SelfCareModel.moodLabel(for: 25) == "Okay")
        precondition(SelfCareModel.moodLabel(for: 50) == "Good")
        precondition(SelfCareModel.moodLabel(for: 75) == "Great")

        let suiteName = "SelfCareSmoke.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let model = SelfCareModel(defaults: defaults)
        precondition(!model.isMet(.exercise))
        model.quickToggle(.exercise)
        precondition(model.isMet(.exercise))

        model.setTheme(.light)
        model.setMood(81)
        let restored = SelfCareModel(defaults: defaults)
        precondition(restored.theme == .light)
        precondition(restored.moodValue == 81)

        defaults.removePersistentDomain(forName: suiteName)
        print("SelfCare model smoke checks passed")
    }
}
