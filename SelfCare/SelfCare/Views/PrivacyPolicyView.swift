import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section {
                Text("Self Care is designed to keep your wellbeing information private and under your control.")
                    .font(.body)
            }

            policySection(
                title: "Data stored on your iPhone",
                text: "Your mood check-ins, factor values, appearance choice, and app preferences are stored "
                    + "locally on this iPhone. Self Care has no account system, advertising, analytics, or "
                    + "developer-operated server."
            )

            policySection(
                title: "Apple Health",
                text: "With your permission, Self Care reads Exercise Time and Sleep Analysis and can save a "
                    + "mood as a State of Mind entry. Apple Health permissions are optional and controlled by "
                    + "you. Self Care does not send Health data to its developers or servers and does not use it "
                    + "for advertising, marketing, or profiling. A CSV export may contain factor values read from "
                    + "Apple Health and is shared only when you choose a destination."
            )

            policySection(
                title: "Export and deletion",
                text: "Self Care exports check-in history only when you choose Export and select a destination. "
                    + "Reset Self Care Data removes the app’s local history and preferences and asks HealthKit to "
                    + "remove State of Mind entries Self Care previously saved. If HealthKit cannot remove those "
                    + "entries, Self Care keeps the local data and reports the problem. Health permissions remain "
                    + "managed by iOS."
            )

            policySection(
                title: "Wellbeing, not medical care",
                text: "Self Care supports personal reflection. It does not diagnose, treat, or prevent any "
                    + "medical condition and is not a substitute for professional care."
            )

            Section {
                Text("Effective October 12, 2026")
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
