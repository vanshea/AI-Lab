import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            SelfCareTheme.darkWallpaper
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: SelfCareTheme.Spacing.large) {
                    Spacer(minLength: SelfCareTheme.Spacing.extraLarge)

                    AppMark(size: 112)

                    VStack(spacing: SelfCareTheme.Spacing.small) {
                        Text("A quiet moment for you")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)

                        Text(
                            "Notice how you feel, reflect on a few daily factors, "
                                + "and build a private history on this iPhone."
                        )
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.82))
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: SelfCareTheme.Spacing.medium) {
                        welcomePoint(
                            symbol: "hand.raised.fill",
                            title: "Private by design",
                            detail: "Your full check-in history stays in this app."
                        )
                        welcomePoint(
                            symbol: "heart.text.square.fill",
                            title: "Apple Health is optional",
                            detail: "If you choose, Self Care can read exercise and sleep "
                                + "and save your mood to State of Mind."
                        )
                        welcomePoint(
                            symbol: "sparkles",
                            title: "No judgment, no diagnosis",
                            detail: "Self Care is a wellbeing journal, not medical advice."
                        )
                    }
                    .padding(SelfCareTheme.Spacing.large)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 24, style: .continuous))

                    Button("Begin my check-in", systemImage: "arrow.right") {
                        onContinue()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                    Text("You can connect Apple Health later in Settings.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, SelfCareTheme.Spacing.large)
                .padding(.bottom, SelfCareTheme.Spacing.extraLarge)
            }
        }
    }

    private func welcomePoint(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: SelfCareTheme.Spacing.medium) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(SelfCareTheme.accent)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SelfCareTheme.Spacing.extraSmall) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WelcomeView(onContinue: {})
}
