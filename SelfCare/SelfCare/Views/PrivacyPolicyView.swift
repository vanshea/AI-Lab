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
                    + "you. Self Care does not use Health data for advertising, marketing, or profiling and does "
                    + "not sell or share it with third parties."
            )

            policySection(
                title: "Export and deletion",
                text: "Self Care exports check-in history only when you choose Export and select a destination. "
                    + "Reset Self Care Data removes the app’s local history and settings. It does not remove State "
                    + "of Mind entries already saved in Apple Health."
            )

            policySection(
                title: "Wellbeing, not medical care",
                text: "Self Care supports personal reflection. It does not diagnose, treat, or prevent any "
                    + "medical condition and is not a substitute for professional care."
            )

            Section {
                Text("Effective July 22, 2026")
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
