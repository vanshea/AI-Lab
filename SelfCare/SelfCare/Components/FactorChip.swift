import SwiftUI

struct FactorChip: View {
    let factor: FactorKey
    let isMet: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: factor.symbol)
                .accessibilityHidden(true)

            Text(factor.chipLabel)
                .fixedSize(horizontal: false, vertical: true)

            if isMet {
                Image(systemName: "checkmark.circle.fill")
                    .accessibilityHidden(true)
            }
        }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isMet ? .white : .secondary)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(
                isMet ? SelfCareTheme.goalMet : Color.secondary.opacity(0.14),
                in: .capsule
            )
            .contentShape(Capsule())
            .gesture(
                LongPressGesture(minimumDuration: 0.55)
                    .exclusively(before: TapGesture())
                    .onEnded { result in
                        switch result {
                        case .first:
                            onLongPress()
                        case .second:
                            onTap()
                        }
                    }
            )
            .accessibilityLabel(factor.chipLabel)
            .accessibilityValue(isMet ? "Goal met" : "Goal not met")
            .accessibilityHint("Double-tap to toggle. Long press to edit the value.")
            .accessibilityAddTraits(isMet ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction(named: "Edit \(factor.label)") {
                onLongPress()
            }
    }
}

struct AdaptiveFactorChips: View {
    @Bindable var model: SelfCareModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 7) {
                chips
            }

            VStack(alignment: .leading, spacing: 8) {
                chips
            }
        }
    }

    @ViewBuilder
    private var chips: some View {
        ForEach(FactorKey.allCases) { factor in
            FactorChip(
                factor: factor,
                isMet: model.isMet(factor),
                onTap: { model.quickToggle(factor) },
                onLongPress: { model.editingFactor = factor }
            )
        }
    }
}
