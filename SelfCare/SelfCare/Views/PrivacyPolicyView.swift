import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section {
                Text("Self Care is designed to keep your wellbeing information private and under your control.")
                    .font(.body)
            }

            policySection(
                title: "Information on your iPhone",
                text: "Your mood check-ins, factor values, completed goals, custom categories, reminder time, "
                    + "appearance choice, and app preferences are stored locally on this iPhone. Self Care has "
                    + "no account system or developer-operated server."
            )

            policySection(
                title: "Apple Health",
                text: "With your permission, Self Care reads Exercise Time and Sleep Analysis and can save a "
                    + "mood and meaningful check-in associations as a State of Mind entry. Apple Health access "
                    + "is optional and controlled by you. Self Care does not send Health data to the developer, "
                    + "sell it, or use it for advertising, marketing, profiling, or data mining."
            )

            policySection(
                title: "Reminders",
                text: "If you enable a daily reminder, the preference and time stay on this iPhone and iOS "
                    + "schedules the notification. Self Care does not use a remote notification server."
            )

            policySection(
                title: "No tracking",
                text: "Self Care contains no developer-operated analytics, advertising, cross-app tracking, or "
                    + "profiling tools and uses no third-party advertising or analytics SDKs."
            )

            policySection(
                title: "Export and deletion",
                text: "Self Care exports check-in history only when you choose Export and select a destination. "
                    + "That destination’s privacy practices then apply. Reset Self Care Data removes the app’s "
                    + "local history and preferences and asks HealthKit to "
                    + "remove State of Mind entries Self Care previously saved. If HealthKit cannot remove those "
                    + "entries, Self Care keeps the local data and reports the problem. Health permissions remain "
                    + "managed by iOS."
            )

            policySection(
                title: "Retention and backups",
                text: "Local information remains until you delete a check-in, reset the app, or uninstall it. "
                    + "Uninstalling does not necessarily delete State of Mind entries already in Apple Health. "
                    + "Apple may include local app data in an Apple-managed device backup, depending on your "
                    + "backup settings. Self Care does not receive those backups."
            )

            policySection(
                title: "Wellbeing, not medical care",
                text: "Self Care supports personal reflection. It does not diagnose, treat, or prevent any "
                    + "medical condition and is not a substitute for professional care."
            )

            Section {
                Link("Privacy questions: vanshea.com", destination: URL(string: "https://www.vanshea.com")!)
                Text("Effective October 19, 2026")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.large)
    }

    private func policySection(title: String, text: String) -> some View {
        Section(title) {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
