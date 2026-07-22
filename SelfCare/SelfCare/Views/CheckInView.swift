import SwiftUI

struct CheckInView: View {
    @Bindable var model: SelfCareModel
    @Bindable var healthKit: HealthKitManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ScaledMetric(relativeTo: .largeTitle) private var clockSize: CGFloat = 88
    @State private var isMinimized = false
    @State private var cardScale = 1.0
    @State private var scaleAtDragStart = 1.0
    @State private var isSavingCheckIn = false
    @State private var checkInMessage: String?

    var body: some View {
        ZStack {
            wallpaper
                .ignoresSafeArea()

            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                standardLayout
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.success, trigger: model.checkIns.count)
    }

    private var standardLayout: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .gesture(backgroundResizeGesture)

            VStack(spacing: 0) {
                resizeHint
                    .padding(.top, 14)

                clock
                    .padding(.top, 28)

                Spacer(minLength: 20)
            }

            VStack {
                Spacer(minLength: 180)

                Group {
                    if isMinimized {
                        minimizedCard
                            .transition(.scale(scale: 0.88).combined(with: .opacity))
                    } else {
                        checkInCard
                            .transition(.scale(scale: 0.94).combined(with: .opacity))
                    }
                }
                .scaleEffect(cardScale, anchor: .bottom)
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
            }
        }
    }

    private var accessibilityLayout: some View {
        ScrollView {
            VStack(spacing: SelfCareTheme.Spacing.large) {
                clock
                    .padding(.top, SelfCareTheme.Spacing.large)

                Group {
                    if isMinimized {
                        minimizedCard
                    } else {
                        checkInCard
                    }
                }
                .padding(.bottom, SelfCareTheme.Spacing.large)
            }
            .padding(.horizontal, SelfCareTheme.Spacing.large)
        }
        .scrollIndicators(.hidden)
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

    private var resizeHint: some View {
        Label("Drag the background to resize the check-in", systemImage: "arrow.up.and.down")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(clockForeground.opacity(0.66))
            .accessibilityHidden(true)
    }

    private var clock: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(spacing: 4) {
                Text(context.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.headline)

                Text(context.date.formatted(.dateTime.hour().minute()))
                    .font(.system(size: min(clockSize, 108), weight: .semibold, design: .rounded))
                    .tracking(-2)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
            }
            .foregroundStyle(clockForeground)
            .accessibilityElement(children: .combine)
        }
    }

    private var minimizedCard: some View {
        Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) {
                isMinimized = false
            }
        } label: {
            HStack(spacing: 10) {
                AppMark(size: 30)

                ForEach(FactorKey.allCases) { factor in
                    Image(systemName: factor.symbol)
                        .font(.caption.weight(.semibold))
                        .opacity(model.isMet(factor) ? 1 : 0.28)
                        .accessibilityHidden(true)
                }

                Circle()
                    .fill(SelfCareTheme.moodDot(value: model.moodValue))
                    .frame(width: 9, height: 9)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: .capsule)
            .overlay {
                Capsule()
                    .stroke(borderColor, lineWidth: 2)
            }
            .shadow(color: .black.opacity(0.30), radius: 15, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Self Care check-in")
    }

    private var checkInCard: some View {
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

            AdaptiveFactorChips(model: model)
                .padding(.top, 14)

            Text("Tap to toggle · hold to set up")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 6)

            Divider()
                .padding(.vertical, 14)

            Text("Take a slow breath. Naming how you feel is the first step of today’s check-in.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                saveCheckIn()
            } label: {
                Label(
                    isSavingCheckIn ? "Saving…" : "Log check-in",
                    systemImage: isSavingCheckIn ? "heart.fill" : "checkmark"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 12)
            .disabled(isSavingCheckIn)

            if let checkInMessage {
                Text(checkInMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(SelfCareTheme.moodTint(value: model.moodValue, isDark: colorScheme == .dark))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(borderColor, lineWidth: 2.5)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.42 : 0.16), radius: 18, y: 9)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: model.completedFactorCount)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                minimizeCheckIn()
            } label: {
                HStack(spacing: 12) {
                    AppMark(size: 48)

                    Text("Self Care")
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text("\(model.completedFactorCount)/\(FactorKey.allCases.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(borderColor, in: .capsule)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Self Care, \(model.completedFactorCount) of \(FactorKey.allCases.count) daily goals")
            .accessibilityHint("Minimizes the check-in")

            Spacer(minLength: 4)

            NavigationLink {
                SettingsView(model: model, healthKit: healthKit)
            } label: {
                Image(systemName: "gearshape.fill")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Settings")
        }
    }

    private var borderColor: Color {
        model.completedFactorCount == 0
            ? Color.secondary.opacity(0.35)
            : SelfCareTheme.goalMet.opacity(0.48 + Double(model.completedFactorCount) * 0.17)
    }

    private var clockForeground: Color {
        colorScheme == .dark ? .white.opacity(0.94) : .black.opacity(0.78)
    }

    private var backgroundResizeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { gesture in
                let proposed = scaleAtDragStart - (gesture.translation.height / 260)
                cardScale = min(1.28, max(0.78, proposed))
            }
            .onEnded { _ in
                scaleAtDragStart = cardScale
            }
    }

    private func saveCheckIn() {
        guard !isSavingCheckIn else { return }
        isSavingCheckIn = true
        checkInMessage = nil

        let checkIn = model.logCheckIn()
        Task {
            do {
                if let sampleID = try await healthKit.saveCheckInMood(checkIn.moodValue, at: checkIn.date) {
                    model.updateHealthSync(for: checkIn.id, state: .synced, sampleID: sampleID)
                    checkInMessage = "Saved here and to Apple Health."
                } else {
                    model.updateHealthSync(for: checkIn.id, state: .unavailable)
                    checkInMessage = "Saved here. Apple Health mood export isn’t available on this device."
                }
            } catch {
                model.updateHealthSync(for: checkIn.id, state: .failed)
                checkInMessage = "Saved here. \(error.localizedDescription)"
            }
            isSavingCheckIn = false
        }
    }

    private func minimizeCheckIn() {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) {
            isMinimized = true
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
