import SwiftUI

struct FactorEditorView: View {
    @Bindable var model: SelfCareModel
    @Bindable var healthKit: HealthKitManager
    let factor: FactorKey

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            if factor.supportsHealthKit {
                Section {
                    Picker(
                        "Entry method",
                        selection: Binding(
                            get: { model.state(for: factor).mode },
                            set: { setInputMode($0) }
                        )
                    ) {
                        Text("Apple Health").tag(InputMode.automatic)
                        Text("Manual").tag(InputMode.manual)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityLabel("Entry method")
                } header: {
                    Text(factor.prompt)
                } footer: {
                    Text("Apple Health is read-only. You can change access later in the Health app.")
                }
            } else {
                Section {
                    Label("Manual entry", systemImage: "hand.tap")
                        .foregroundStyle(.secondary)
                } header: {
                    Text(factor.prompt)
                } footer: {
                    Text("General Screen Time totals are not available through HealthKit, so scrolling remains manual.")
                }
            }

            if model.state(for: factor).mode == .automatic {
                Section {
                    HStack {
                        Label(healthKit.status.title, systemImage: healthKit.status.symbol)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if healthKit.isLoading {
                            ProgressView()
                        }
                    }

                    if model.hasHealthValue(for: factor) {
                        LabeledContent(
                            factor == .exercise ? "Today" : "Last night",
                            value: "\(SelfCareModel.format(model.value(for: factor))) \(factor.unit)"
                        )
                    } else if !healthKit.isLoading {
                        ContentUnavailableView(
                            "No readable \(factor.label.lowercased()) data",
                            systemImage: factor.symbol,
                            description: Text("Check this data type in the Health app, then refresh.")
                        )
                    }

                    Button("Refresh from Apple Health", systemImage: "arrow.clockwise") {
                        syncHealth(requestAuthorization: !healthKit.hasRequestedAuthorization)
                    }
                    .disabled(healthKit.isLoading || healthKit.status == .unavailable)
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text(
                        "For privacy, HealthKit does not tell apps whether an individual read permission was denied. "
                            + "No data can also mean there are no matching samples."
                    )
                }
            } else {
                Section("Manual value") {
                    HStack {
                        TextField(
                            "Value",
                            value: Binding(
                                get: { model.state(for: factor).manualValue },
                                set: { model.setManualValue($0, for: factor) }
                            ),
                            format: .number.precision(.fractionLength(0...1))
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)

                        Text(factor.unit)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Today’s goal") {
                LabeledContent("Target", value: factor.goalDescription)

                if model.state(for: factor).mode == .automatic && !model.hasHealthValue(for: factor) {
                    Label("Waiting for Health data", systemImage: "heart.text.square")
                        .foregroundStyle(.secondary)
                } else {
                    Label(
                        model.isMet(factor) ? "Meets today’s goal" : "Below today’s goal",
                        systemImage: model.isMet(factor) ? "checkmark.circle.fill" : "circle.dashed"
                    )
                    .foregroundStyle(model.isMet(factor) ? SelfCareTheme.goalMet : .secondary)
                }
            }
        }
        .navigationTitle("\(factor.label) setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", systemImage: "xmark") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Done", systemImage: "checkmark") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func setInputMode(_ mode: InputMode) {
        model.setMode(mode, for: factor)
        guard mode == .automatic else { return }
        syncHealth(requestAuthorization: !healthKit.hasRequestedAuthorization)
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
