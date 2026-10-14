import SwiftUI
import UIKit

struct SettingsView: View {
    @Bindable var model: SelfCareModel
    @Bindable var healthKit: HealthKitManager
    @Bindable var reminders: CheckInReminderService
    @Environment(\.openURL) private var openURL
    @State private var isConfirmingReset = false
    @State private var editingCategory: SelfCareCategory?
    @State private var categoryPendingDeletion: SelfCareCategory?
    @State private var categoryErrorMessage: String?
    @State private var isUpdatingMoodExport = false
    @State private var isResettingData = false
    @State private var resetErrorMessage: String?

    private let suggestedCategories = [
        (name: "Connection", subtitle: "Moments of connection today"),
        (name: "Creativity", subtitle: "Creative moments today"),
        (name: "Diet", subtitle: "Nourishing choices today"),
        (name: "Fun", subtitle: "Fun moments today"),
        (name: "Intimacy", subtitle: "Moments of intimacy today"),
        (name: "Mindfulness", subtitle: "Mindful moments today"),
        (name: "Prayer", subtitle: "Prayer moments today")
    ]

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
                Picker(
                    "Check-in reminder",
                    selection: Binding(
                        get: { reminders.openingPreference },
                        set: { preference in
                            Task {
                                await reminders.selectPreference(preference)
                            }
                        }
                    )
                ) {
                    Text("Open manually").tag(CheckInOpeningPreference.manual)
                    Text("Remind me daily").tag(CheckInOpeningPreference.dailyReminder)
                }
                .pickerStyle(.segmented)

                if reminders.openingPreference == .dailyReminder {
                    DatePicker(
                        "Reminder time",
                        selection: Binding(
                            get: { reminders.reminderTime },
                            set: { date in
                                Task {
                                    await reminders.setReminderTime(date)
                                }
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }

                Label(reminders.authorizationDescription, systemImage: reminderStatusSymbol)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let errorMessage = reminders.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if reminders.canOpenSystemSettings {
                    Button("Open notification settings", systemImage: "gear") {
                        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else {
                            return
                        }
                        openURL(url)
                    }
                }
            } header: {
                Text("Check-in reminder")
            } footer: {
                Text(
                    reminders.openingPreference == .manual
                        ? "Self Care will not schedule a notification. Open the app whenever you choose."
                        : "iOS will show one daily notification at your selected local time. "
                            + "The app opens only when you tap it."
                )
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
                ForEach(suggestedCategories, id: \.name) { suggested in
                    let existing = model.customCategories.first {
                        $0.name.localizedCaseInsensitiveCompare(suggested.name) == .orderedSame
                    }

                    HStack(spacing: 12) {
                        if let iconName = SelfCareOptionIcon.assetName(for: suggested.name) {
                            SelfCareOptionIcon(name: iconName, size: 24)
                                .frame(width: 24)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggested.name)
                            Text(suggested.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if existing != nil {
                            Label("Added", systemImage: "checkmark.circle.fill")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        } else {
                            Button("Add") {
                                do {
                                    try model.addCategory(named: suggested.name)
                                    categoryErrorMessage = nil
                                } catch {
                                    categoryErrorMessage = error.localizedDescription
                                }
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Add \(suggested.name) to daily factors")
                        }
                    }
                }

                if let categoryErrorMessage {
                    Text(categoryErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Suggested categories")
            } footer: {
                Text("Add only the categories you want to include in your daily check-in.")
            }

            Section {
                if model.customCategories.isEmpty {
                    Text("No custom categories yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.customCategories) { category in
                        Button {
                            editingCategory = category
                        } label: {
                            HStack(spacing: 12) {
                                if let iconName = SelfCareOptionIcon.assetName(for: category.name) {
                                    SelfCareOptionIcon(name: iconName, size: 24)
                                        .frame(width: 24)
                                } else {
                                    Image(systemName: category.linkedHealthDataType?.symbol ?? "heart")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.name)
                                        .foregroundStyle(.primary)
                                    Text(
                                        category.source == .appleHealth
                                            ? "Apple Health · \(category.linkedHealthDataType?.title ?? "Unavailable type")"
                                            : "Manual"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .accessibilityLabel(
                            "\(category.name), "
                                + (category.source == .appleHealth ? "connected to Apple Health" : "manual")
                        )
                        .accessibilityHint("Opens category settings")
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                categoryPendingDeletion = category
                            }
                        }
                    }
                }

                Button("Add category", systemImage: "plus") {
                    editingCategory = SelfCareCategory(
                        id: UUID(),
                        name: "",
                        source: .manual,
                        healthDataTypeIdentifier: nil,
                        isUserCreated: true
                    )
                }

                if let categoryErrorMessage {
                    Text(categoryErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Custom categories")
            } footer: {
                Text("Renaming or deleting a category does not change historical check-in snapshots.")
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

                Toggle(
                    "Save check-in mood to State of Mind",
                    isOn: Binding(
                        get: { healthKit.isMoodExportEnabled },
                        set: { enabled in
                            isUpdatingMoodExport = true
                            Task {
                                await healthKit.setMoodExportEnabled(enabled)
                                isUpdatingMoodExport = false
                            }
                        }
                    )
                )
                .disabled(isUpdatingMoodExport || healthKit.status == .unavailable)

                if isUpdatingMoodExport {
                    ProgressView("Updating mood export…")
                        .font(.footnote)
                }

                if let errorMessage = healthKit.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Apple Health")
            } footer: {
                Text(
                    "Exercise Time and Sleep Analysis access is requested only when you connect those categories. "
                        + "Mood export requests separate State of Mind access only when you turn it on."
                )
            }

            Section {
                if let privacyPolicyURL = AppStoreLinks.privacyPolicyURL {
                    Link(destination: privacyPolicyURL) {
                        Label("Privacy policy online", systemImage: "arrow.up.right.square")
                    }
                } else {
                    Label("Online privacy policy URL not configured", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }

                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    Label("Privacy details", systemImage: "hand.raised.fill")
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
                .disabled(isResettingData)

                if isResettingData {
                    ProgressView("Removing saved data…")
                }
            } header: {
                Text("Privacy & data")
            } footer: {
                Text(
                    "Export only shares data when you choose a destination. Reset removes local settings and "
                        + "check-in history, plus Self Care-authored State of Mind entries when HealthKit allows it. "
                        + "Health permissions remain controlled in iOS Settings."
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
                resetAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This removes local check-ins, preferences, and Self Care-authored State of Mind entries. "
                    + "If HealthKit cannot remove its entries, the local reset will be canceled."
            )
        }
        .sheet(item: $editingCategory) { category in
            CategoryEditorView(
                model: model,
                healthKit: healthKit,
                category: model.customCategories.contains(where: { $0.id == category.id }) ? category : nil
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Delete \(categoryPendingDeletion?.name ?? "this category")?",
            isPresented: Binding(
                get: { categoryPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        categoryPendingDeletion = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete category", role: .destructive) {
                deletePendingCategory()
            }
            Button("Cancel", role: .cancel) {
                categoryPendingDeletion = nil
            }
        } message: {
            Text("The category will be removed from future check-ins. Historical records will be preserved.")
        }
        .task {
            await reminders.refreshAuthorizationStatus()
        }
        .alert("Couldn’t reset Self Care", isPresented: Binding(
            get: { resetErrorMessage != nil && !isResettingData },
            set: { if !$0 { resetErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { resetErrorMessage = nil }
        } message: {
            Text(resetErrorMessage ?? "Your local data was kept.")
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

    private var reminderStatusSymbol: String {
        switch reminders.authorizationStatus {
        case .authorized, .provisional, .ephemeral: "bell.badge.fill"
        case .denied: "bell.slash.fill"
        case .notDetermined: "bell"
        @unknown default: "questionmark.circle"
        }
    }

    private func deletePendingCategory() {
        guard let category = categoryPendingDeletion else { return }
        do {
            try model.deleteCategory(id: category.id)
            categoryErrorMessage = nil
        } catch {
            categoryErrorMessage = error.localizedDescription
        }
        categoryPendingDeletion = nil
    }

    private func resetAllData() {
        let exportedCheckIns = model.checkIns.filter { $0.healthSyncState == .synced }
        isResettingData = true
        resetErrorMessage = nil
        Task {
            do {
                for checkIn in exportedCheckIns {
                    try await healthKit.deleteCheckInMood(for: checkIn.id)
                }
                model.resetAllData()
                healthKit.resetPreferences()
                await reminders.resetPreferences()
            } catch {
                resetErrorMessage = "Local data was kept. Couldn’t remove an Apple Health entry: \(error.localizedDescription)"
            }
            isResettingData = false
        }
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

private enum AppStoreLinks {
    // Replace with the hosted, public HTTPS policy URL before release.
    static let privacyPolicyURLString = "REPLACE_WITH_PUBLIC_PRIVACY_POLICY_HTTPS_URL"

    static var privacyPolicyURL: URL? {
        guard
            let url = URL(string: privacyPolicyURLString),
            url.scheme == "https",
            url.host?.isEmpty == false,
            !privacyPolicyURLString.contains("REPLACE_WITH")
        else {
            return nil
        }
        return url
    }
}
