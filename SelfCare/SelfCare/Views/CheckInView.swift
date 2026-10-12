import SwiftUI
import Observation

enum SnackbarPresentationState: Equatable {
    case full
    case compact
    case minimal

    var afterOutsideTap: Self {
        switch self {
        case .full: .compact
        case .compact: .minimal
        case .minimal: .minimal
        }
    }

    var afterSnackbarTap: Self {
        switch self {
        case .minimal: .full
        case .full, .compact: self
        }
    }
}

private struct SnackbarFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

enum CheckInEntryPoint: Equatable {
    case normalApplication
    case transientPresentation
}

enum CheckInCompletionOutcome: Equatable {
    case returnToRoot
    case dismissTransientPresentation
}

@MainActor
@Observable
final class CheckInCompletionCoordinator {
    enum Phase: Equatable {
        case idle
        case saving
        case saved
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var healthDetail: String?
    private(set) var outcome: CheckInCompletionOutcome = .returnToRoot

    func save(
        model: SelfCareModel,
        healthKit: HealthKitManager,
        entryPoint: CheckInEntryPoint
    ) async -> Bool {
        guard phase != .saving else { return false }
        phase = .saving
        healthDetail = nil

        let checkIn: CheckInRecord
        do {
            checkIn = try model.logCheckIn()
        } catch {
            phase = .failed(error.localizedDescription)
            return false
        }

        if healthKit.isMoodExportEnabled {
            do {
                let syncVersion = model.nextHealthSyncVersion(for: checkIn.id) ?? 1
                if let sampleID = try await healthKit.saveCheckInMood(checkIn, syncVersion: syncVersion) {
                    model.updateHealthSync(for: checkIn.id, state: .synced, sampleID: sampleID)
                    healthDetail = "Also saved to Apple Health."
                } else {
                    model.updateHealthSync(for: checkIn.id, state: .unavailable)
                    healthDetail = "Saved on this iPhone. Apple Health mood export isn’t available."
                }
            } catch {
                model.updateHealthSync(for: checkIn.id, state: .failed)
                healthDetail = "Saved on this iPhone. \(error.localizedDescription)"
            }
        } else {
            model.updateHealthSync(for: checkIn.id, state: .notRequested)
            healthDetail = "Saved on this iPhone."
        }

        phase = .saved
        outcome = entryPoint == .transientPresentation
            ? .dismissTransientPresentation
            : .returnToRoot
        return true
    }

    func reset() {
        phase = .idle
        healthDetail = nil
        outcome = .returnToRoot
    }
}

struct CheckInView: View {
    @Bindable var model: SelfCareModel
    @Bindable var healthKit: HealthKitManager
    @Bindable var reminders: CheckInReminderService
    @Binding var presentationState: SnackbarPresentationState
    var entryPoint: CheckInEntryPoint = .normalApplication

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ScaledMetric(relativeTo: .largeTitle) private var clockSize: CGFloat = 82
    @State private var completionCoordinator = CheckInCompletionCoordinator()
    @State private var isAddingCategory = false
    @State private var snackbarFrame: CGRect = .zero
    @AccessibilityFocusState private var isAddCategoryFocused: Bool

    var body: some View {
        ZStack {
            wallpaper
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: SelfCareTheme.Spacing.large) {
                    clock
                        .padding(.top, SelfCareTheme.Spacing.medium)

                    snackbar
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, SelfCareTheme.Spacing.medium)
                        .background {
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: SnackbarFramePreferenceKey.self,
                                    value: proxy.frame(in: .named("checkInScreen"))
                                )
                            }
                        }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, SelfCareTheme.Spacing.large)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .coordinateSpace(name: "checkInScreen")
        .onPreferenceChange(SnackbarFramePreferenceKey.self) { snackbarFrame = $0 }
        .simultaneousGesture(
            SpatialTapGesture()
                .onEnded { event in
                    guard !snackbarFrame.isEmpty,
                          !snackbarFrame.contains(event.location) else { return }
                    advancePresentationState()
                },
            including: .gesture
        )
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isAddingCategory) {
            CategoryEditorView(model: model, healthKit: healthKit)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: isAddingCategory) { _, isPresented in
            if !isPresented {
                isAddCategoryFocused = true
            }
        }
        .sensoryFeedback(.success, trigger: model.checkIns.count)
    }

    @ViewBuilder
    private var snackbar: some View {
        switch presentationState {
        case .full:
            fullCard
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        case .compact:
            compactCard
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        case .minimal:
            minimalCard
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private var wallpaper: some View {
        ZStack {
            colorScheme == .dark ? SelfCareTheme.darkWallpaper : SelfCareTheme.lightWallpaper

            RadialGradient(
                colors: [.white.opacity(0.11), .clear],
                center: UnitPoint(x: 0.5, y: 0.18),
                startRadius: 0,
                endRadius: 340
            )
        }
    }

    private var clock: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(spacing: 4) {
                Text(context.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.headline)

                Text(context.date.formatted(.dateTime.hour().minute()))
                    .font(.system(size: min(clockSize, 104), weight: .semibold, design: .rounded))
                    .tracking(-2)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
            }
            .foregroundStyle(clockForeground)
            .accessibilityElement(children: .combine)
        }
    }

    private var fullCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Text("How are you feeling right now?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 9)

            MoodSlider(
                value: Binding(
                    get: { model.moodValue },
                    set: { model.setMood($0) }
                ),
                label: model.moodLabel
            )
            .padding(.top, 12)

            HStack {
                Text("Low")
                Spacer()
                Text("Great")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)

            categoryGrid
                .padding(.top, 14)

            Text("Tap to toggle · hold built-in categories to set up")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 6)

            Divider()
                .padding(.vertical, 14)

            Text("Take a slow breath. Naming how you feel is the first step of today’s check-in.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            checkInAction
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(cardBackground)
        .overlay(cardBorder)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.42 : 0.16), radius: 18, y: 9)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Full check-in panel")
    }

    private var compactCard: some View {
        VStack(spacing: SelfCareTheme.Spacing.medium) {
            HStack(spacing: SelfCareTheme.Spacing.medium) {
                AppMark(size: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Self Care")
                        .font(.headline)
                    Text("\(model.completedCategoryCount) of \(model.totalCategoryCount) categories complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Button {
                    setPresentationState(.minimal)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Minimize check-in panel")
            }

            checkInAction
        }
        .padding(16)
        .background(cardBackground)
        .overlay(cardBorder)
        .shadow(color: .black.opacity(0.22), radius: 14, y: 7)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Compact check-in panel")
    }

    private var minimalCard: some View {
        Button {
            setPresentationState(presentationState.afterSnackbarTap)
        } label: {
            HStack(spacing: 10) {
                AppMark(size: 30)

                Text("Self Care")
                    .font(.subheadline.weight(.semibold))

                Text("\(model.completedCategoryCount)/\(model.totalCategoryCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Image(systemName: "house.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(.regularMaterial, in: .capsule)
            .overlay {
                Capsule().stroke(borderColor, lineWidth: 1.5)
            }
            .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Return to full check-in")
        .accessibilityValue("\(model.completedCategoryCount) of \(model.totalCategoryCount) categories complete")
    }

    private var header: some View {
        HStack(spacing: SelfCareTheme.Spacing.medium) {
            AppMark(size: 44)

            VStack(alignment: .leading, spacing: 1) {
                Text("Self Care")
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text("\(model.completedCategoryCount) of \(model.totalCategoryCount) complete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Button {
                setPresentationState(.compact)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Minimize check-in panel")

            NavigationLink {
                SettingsView(model: model, healthKit: healthKit, reminders: reminders)
            } label: {
                Image(systemName: "gearshape.fill")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Settings")
        }
    }

    private var categoryGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 180 : 108), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(FactorKey.allCases) { factor in
                FactorChip(
                    factor: factor,
                    isMet: model.isMet(factor),
                    onTap: { model.quickToggle(factor) },
                    onLongPress: { model.editingFactor = factor }
                )
            }

            ForEach(model.customCategories) { category in
                customCategoryChip(category)
            }

            Button {
                isAddCategoryFocused = false
                isAddingCategory = true
            } label: {
                Label("Add", systemImage: "plus")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .background(Color.secondary.opacity(0.10), in: .capsule)
            .overlay {
                Capsule().stroke(Color.secondary.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4]))
            }
            .accessibilityLabel("Add self-care category")
            .accessibilityFocused($isAddCategoryFocused)
        }
    }

    private func customCategoryChip(_ category: SelfCareCategory) -> some View {
        let isCompleted = model.isCustomCategoryCompleted(category)
        return Button {
            model.toggleCustomCategory(category.id)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.linkedHealthDataType?.symbol ?? "heart")
                    .accessibilityHidden(true)

                Text(category.name)
                    .fixedSize(horizontal: false, vertical: true)

                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .accessibilityHidden(true)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isCompleted ? .white : .secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 10)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(isCompleted ? SelfCareTheme.goalMet : Color.secondary.opacity(0.14), in: .capsule)
        .accessibilityLabel(category.name)
        .accessibilityValue(isCompleted ? "Complete" : "Not complete")
        .accessibilityHint("Double-tap to toggle this category.")
    }

    private var checkInAction: some View {
        VStack(spacing: 6) {
            if model.hasCheckedInToday() {
                Text("Check-in is done today, add another?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Check-in is done today. You can add another.")
            }

            Button {
                saveCheckIn()
            } label: {
                Label(checkInButtonTitle, systemImage: checkInButtonSymbol)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GlassCheckInButtonStyle())
            .disabled(completionCoordinator.phase == .saving)
            .accessibilityHint("Saves this check-in before closing the expanded panel.")

            if let message = completionMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(completionMessageIsError ? Color.red : Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 12)
    }

    private var checkInButtonTitle: String {
        switch completionCoordinator.phase {
        case .saving: "Saving…"
        case .saved: "Check-in saved"
        default: "Check in"
        }
    }

    private var checkInButtonSymbol: String {
        switch completionCoordinator.phase {
        case .saving: "ellipsis"
        case .saved: "checkmark.circle.fill"
        default: "checkmark"
        }
    }

    private var completionMessage: String? {
        switch completionCoordinator.phase {
        case let .failed(message): message
        case .saved: completionCoordinator.healthDetail
        default: nil
        }
    }

    private var completionMessageIsError: Bool {
        if case .failed = completionCoordinator.phase { return true }
        return false
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(.regularMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(SelfCareTheme.moodTint(value: model.moodValue, isDark: colorScheme == .dark))
            }
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .stroke(borderColor, lineWidth: 1.5)
    }

    private var borderColor: Color {
        model.completedCategoryCount == 0
            ? Color.secondary.opacity(0.38)
            : SelfCareTheme.goalMet.opacity(0.62)
    }

    private var clockForeground: Color {
        colorScheme == .dark ? .white.opacity(0.94) : .black.opacity(0.78)
    }

    private func advancePresentationState() {
        setPresentationState(presentationState.afterOutsideTap)
    }

    private func setPresentationState(_ newState: SnackbarPresentationState) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            presentationState = newState
        }
    }

    private func saveCheckIn() {
        Task {
            let didSave = await completionCoordinator.save(
                model: model,
                healthKit: healthKit,
                entryPoint: .normalApplication
            )
            guard didSave else { return }
            AccessibilityNotification.Announcement("Check-in saved").post()
            try? await Task.sleep(for: .milliseconds(1_200))
            switch completionCoordinator.outcome {
            case .returnToRoot:
                setPresentationState(.minimal)
            case .dismissTransientPresentation:
                dismiss()
            }
            completionCoordinator.reset()
        }
    }
}

struct GlassCheckInButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(reduceTransparency ? Color.white : Color.primary)
            .padding(.horizontal, 18)
            .frame(minHeight: 50)
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(SelfCareTheme.accent)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.regularMaterial)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        contrast == .increased ? Color.primary : Color.white.opacity(0.36),
                        lineWidth: contrast == .increased ? 2 : 1
                    )
            }
            .shadow(color: .black.opacity(reduceTransparency ? 0 : 0.12), radius: 4, y: 2)
            .opacity(isEnabled ? 1 : 0.55)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct CategoryEditorView: View {
    @Bindable var model: SelfCareModel
    @Bindable var healthKit: HealthKitManager
    var category: SelfCareCategory?

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool
    @State private var name = ""
    @State private var connectsToHealth = false
    @State private var selectedHealthType = SupportedHealthDataType.exerciseTime
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    TextField("Category name", text: $name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($isNameFocused)
                        .onSubmit(save)
                        .accessibilityLabel("Self-care category name")
                }

                Section {
                    Toggle("Connect to Apple Health", isOn: $connectsToHealth)

                    if connectsToHealth {
                        Picker("Health data type", selection: $selectedHealthType) {
                            ForEach(SupportedHealthDataType.allCases) { type in
                                Label(type.title, systemImage: type.symbol).tag(type)
                            }
                        }
                    }
                } footer: {
                    Text(
                        connectsToHealth
                            ? "Self Care requests access only to the selected supported data type. "
                                + "If access is unavailable, you can still check this category manually."
                            : "Manual categories do not request Apple Health access."
                    )
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .navigationTitle(category == nil ? "Add category" : "Edit category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let category {
                    name = category.name
                    connectsToHealth = category.source == .appleHealth
                    selectedHealthType = category.linkedHealthDataType ?? .exerciseTime
                }
                isNameFocused = true
            }
        }
    }

    private func save() {
        let selectedType = connectsToHealth ? selectedHealthType : nil
        do {
            if let category {
                try model.updateCategory(id: category.id, name: name, healthDataType: selectedType)
            } else {
                try model.addCategory(named: name, healthDataType: selectedType)
            }
            AccessibilityNotification.Announcement("Self-care category saved").post()
            dismiss()

            guard let selectedType else { return }
            Task {
                await healthKit.requestAuthorization(for: selectedType)
                model.updateHealthValues(
                    exerciseMinutes: healthKit.exerciseMinutes,
                    sleepHours: healthKit.sleepHours
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AppMark: View {
    let size: CGFloat

    var body: some View {
        Image("AppMark")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * 0.24, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
            .accessibilityHidden(true)
    }
}

#Preview {
    @Previewable @State var state = SnackbarPresentationState.full
    CheckInView(
        model: SelfCareModel(),
        healthKit: HealthKitManager(),
        reminders: CheckInReminderService(),
        presentationState: $state
    )
}
