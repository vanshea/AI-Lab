import SwiftUI

struct MoodSlider: View {
    @Binding var value: Double
    let label: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let thumbX = min(width - 13, max(13, width * value / 100))

            ZStack(alignment: .topLeading) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(.thinMaterial, in: .rect(cornerRadius: 8))
                    .fixedSize()
                    .position(x: thumbX, y: 10)

                Capsule()
                    .fill(SelfCareTheme.moodTrack)
                    .frame(height: 8)
                    .position(x: width / 2, y: 37)

                Circle()
                    .fill(.white)
                    .frame(width: 26, height: 26)
                    .shadow(color: .black.opacity(0.32), radius: 4, y: 2)
                    .scaleEffect(isDragging ? 1.16 : 1)
                    .position(x: thumbX, y: 37)
                    .animation(reduceMotion ? nil : .snappy(duration: 0.14), value: isDragging)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        value = min(100, max(0, gesture.location.x / width * 100))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(height: 53)
        .accessibilityRepresentation {
            Slider(value: $value, in: 0...100, step: 5) {
                Text("Mood")
            }
            .accessibilityValue("\(label), \(Int(value.rounded())) out of 100")
            .accessibilityHint("Swipe up or down to adjust in steps of five")
        }
    }
}
