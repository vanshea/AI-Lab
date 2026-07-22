import SwiftUI

struct SettingsView: View {
    @Bindable var model: SelfCareModel
    @Bindable var healthKit: HealthKitManager
    @State private var isConfirmingReset = false

    var body: some View {
        Form {
            if let recoveryMessage = model.persistenceRecoveryMessage {
                Section {
                    Label(recoveryMessage, systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
                        .foregroundStyle(.secondary)

                    Button("Dismiss") {
                        model.dismissPersistenceRecoveryMessage()
                    }
                } header: {
                    Text("Storage recovery")
                }
            }

            Section {
                NavigationLink {
                    CheckInHistoryView(model: model, healthKit: healthKit)
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            } footer: {
                Text("Each entry stores the mood and daily-factor snapshot on this iPhone.")
            }

            Section("Appearance") {
                Picker(
                    "Appearance",
                    selection: Binding(
                        get: { model.theme },
                        set: { model.setTheme($0) }
                    )
                ) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Appearance")
            }

            Section {
                ForEach(FactorKey.allCases) { factor in
                    Button {
                        model.editingFactor = factor
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: factor.symbol)
                                .foregroundStyle(model.isMet(factor) ? SelfCareTheme.goalMet : .secondary)
                                .frame(width: 24)

                            Text(factor.label)
                                .foregroundStyle(.primary)

                            Spacer()

                            Text(model.summary(for: factor))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .accessibilityLabel("\(factor.label), \(model.summary(for: factor))")
                    .accessibilityHint("Opens \(factor.label.lowercased()) setup")
                }
            } header: {
                Text("Daily factors")
            } footer: {
                Text(
                    "Exercise and sleep can update from Apple Health. "
                        + "Scrolling stays manual because it is not a HealthKit data type."
                )
            }

            Section {
                HStack(spacing: 12) {
                    Image(systemName: healthKit.status.symbol)
                        .foregroundStyle(healthStatusColor)
                        .frame(width: 24)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(healthKit.status.title)
                        if let lastUpdated = healthKit.lastUpdated {
                            Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if healthKit.isLoading {
                        ProgressView()
                    }
                }

                Button(
                    healthKit.hasRequestedAuthorization ? "Refresh Apple Health" : "Connect Apple Health",
                    systemImage: healthKit.hasRequestedAuthorization ? "arrow.clockwise" : "heart.fill"
                ) {
                    syncHealth(requestAuthorization: !healthKit.hasRequestedAuthorization)
                }
                .disabled(healthKit.isLoading || healthKit.status == .unavailable)

                if let errorMessage = healthKit.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Apple Health")
            } footer: {
                Text(
                    "Self Care reads Exercise Time and Sleep Analysis. When you log a check-in, it can write "
                        + "the mood to State of Mind. The full check-in history stays in this app."
                )
            }

            Section {
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    Label("Privacy", systemImage: "hand.raised.fill")
                }

                ShareLink(
                    item: model.exportCSV(),
                    subject: Text("Self Care check-in history")
                ) {
                    Label("Export history as CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(model.checkIns.isEmpty)

                Button("Reset Self Care data", systemImage: "trash", role: .destructive) {
                    isConfirmingReset = true
                }
            } header: {
                Text("Privacy & data")
            } footer: {
                Text(
                    "Export only shares data when you choose a destination. Reset removes Self Care’s local "
                        + "settings and check-in history; it does not delete entries already saved in Apple Health."
                )
            }

            Section("About this build") {
                LabeledContent("Version", value: versionText)
                LabeledContent("Storage", value: "On this iPhone")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .confirmationDialog(
            "Reset all Self Care data?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset all data", role: .destructive) {
                model.resetAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This permanently removes local check-ins and settings from this iPhone. "
                    + "Apple Health entries are not changed."
            )
        }
    }

    private var healthStatusColor: Color {
        switch healthKit.status {
        case .ready: SelfCareTheme.goalMet
        case .failed: .orange
        default: .secondary
        }
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func syncHealth(requestAuthorization: Bool) {
        Task {
            if requestAuthorization {
                await healthKit.requestAuthorizationAndRefresh()
            } else {
                await healthKit.refresh()
            }
            model.updateHealthValues(
                exerciseMinutes: healthKit.exerciseMinutes,
                sleepHours: healthKit.sleepHours
            )
        }
    }
}
