import SwiftUI

struct CheckInHistoryView: View {
    @Bindable var model: SelfCareModel
    @Bindable var healthKit: HealthKitManager

    var body: some View {
        Group {
            if model.checkIns.isEmpty {
                ContentUnavailableView(
                    "No check-ins yet",
                    systemImage: "list.clipboard",
                    description: Text("Log a check-in to build your private history.")
                )
            } else {
                List(model.checkIns) { checkIn in
                    NavigationLink {
                        CheckInDetailView(model: model, healthKit: healthKit, checkInID: checkIn.id)
                    } label: {
                        CheckInHistoryRow(checkIn: checkIn)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct CheckInHistoryRow: View {
    let checkIn: CheckInRecord

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(SelfCareTheme.moodDot(value: checkIn.moodValue))
                .frame(width: 34, height: 34)
                .overlay {
                    Text("\(Int(checkIn.moodValue.rounded()))")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(checkIn.moodLabel)
                    .font(.headline)

                Text(checkIn.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("\(checkIn.completedFactorCount) of \(FactorKey.allCases.count) daily goals")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: checkIn.healthSyncState.symbol)
                .foregroundStyle(checkIn.healthSyncState.color)
                .accessibilityLabel(checkIn.healthSyncState.title)
        }
        .padding(.vertical, 4)
    }
}

private struct CheckInDetailView: View {
    @Bindable var model: SelfCareModel
    @Bindable var healthKit: HealthKitManager
    let checkInID: UUID

    @State private var isRetrying = false

    private var checkIn: CheckInRecord? {
        model.checkIns.first(where: { $0.id == checkInID })
    }

    var body: some View {
        Form {
            if let checkIn {
                Section("Mood") {
                    LabeledContent("Feeling", value: checkIn.moodLabel)
                    LabeledContent("Mood value", value: "\(Int(checkIn.moodValue.rounded())) of 100")
                    LabeledContent("Logged", value: checkIn.date.formatted(date: .abbreviated, time: .shortened))
                }

                Section("Daily factors") {
                    ForEach(FactorKey.allCases) { factor in
                        LabeledContent {
                            Text("\(SelfCareModel.format(checkIn.factorValues[factor] ?? 0)) \(factor.unit)")
                        } label: {
                            Label(
                                factor.label,
                                systemImage: checkIn.metFactors.contains(factor)
                                    ? "checkmark.circle.fill"
                                    : factor.symbol
                            )
                            .foregroundStyle(
                                checkIn.metFactors.contains(factor) ? SelfCareTheme.goalMet : .secondary
                            )
                        }
                    }
                }

                Section {
                    Label(checkIn.healthSyncState.title, systemImage: checkIn.healthSyncState.symbol)
                        .foregroundStyle(checkIn.healthSyncState.color)

                    if checkIn.healthSyncState == .failed {
                        Button("Retry Apple Health", systemImage: "arrow.clockwise") {
                            retryHealthSync(checkIn)
                        }
                        .disabled(isRetrying)
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Self Care sends the mood as a State of Mind entry. The factor snapshot remains in this app.")
                }
            }
        }
        .navigationTitle("Check-in")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func retryHealthSync(_ checkIn: CheckInRecord) {
        isRetrying = true
        Task {
            do {
                if let sampleID = try await healthKit.saveCheckInMood(checkIn.moodValue, at: checkIn.date) {
                    model.updateHealthSync(for: checkIn.id, state: .synced, sampleID: sampleID)
                } else {
                    model.updateHealthSync(for: checkIn.id, state: .unavailable)
                }
            } catch {
                model.updateHealthSync(for: checkIn.id, state: .failed)
            }
            isRetrying = false
        }
    }
}

private extension HealthSyncState {
    var title: String {
        switch self {
        case .pending: "Waiting for Apple Health"
        case .synced: "Saved to Apple Health"
        case .unavailable: "Apple Health mood export unavailable"
        case .failed: "Saved here, but not to Apple Health"
        }
    }

    var symbol: String {
        switch self {
        case .pending: "clock"
        case .synced: "heart.fill"
        case .unavailable: "heart.slash"
        case .failed: "exclamationmark.triangle"
        }
    }

    var color: Color {
        switch self {
        case .synced: SelfCareTheme.goalMet
        case .failed: .orange
        default: .secondary
        }
    }
}
