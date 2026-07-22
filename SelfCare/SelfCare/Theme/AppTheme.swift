import SwiftUI

extension AppTheme {
    var colorScheme: ColorScheme {
        switch self {
        case .light: .light
        case .dark: .dark
        }
    }
}

enum SelfCareTheme {
    static let accent = Color.accentColor
    static let goalMet = Color(red: 0.647, green: 0.286, blue: 0.067)

    enum Spacing {
        static let extraSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 20
        static let extraLarge: CGFloat = 32
    }

    static let darkWallpaper = LinearGradient(
        colors: [
            Color(red: 0.079, green: 0.094, blue: 0.194),
            Color(red: 0.063, green: 0.034, blue: 0.108),
            Color(red: 0.010, green: 0.011, blue: 0.034)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let lightWallpaper = LinearGradient(
        colors: [
            Color(red: 0.706, green: 0.835, blue: 0.971),
            Color(red: 0.850, green: 0.714, blue: 0.881),
            Color(red: 0.972, green: 0.843, blue: 0.743)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let moodTrack = LinearGradient(
        colors: [
            Color(red: 0.353, green: 0.640, blue: 0.925),
            Color(red: 0.000, green: 0.783, blue: 0.753),
            Color(red: 0.889, green: 0.762, blue: 0.233),
            Color(red: 0.983, green: 0.476, blue: 0.291)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let appMark = LinearGradient(
        colors: [
            Color(red: 0.000, green: 0.688, blue: 0.721),
            accent
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func moodTint(value: Double, isDark: Bool) -> Color {
        let normalized = min(1, max(0, value / 100))
        let distance = abs(normalized - 0.5) * 2
        let alpha = (isDark ? 0.10 : 0.07) + (distance * (isDark ? 0.18 : 0.12))

        if normalized < 0.5 {
            return Color(red: 0.20, green: 0.43, blue: 0.72).opacity(alpha)
        }
        return Color(red: 0.93, green: 0.47, blue: 0.20).opacity(alpha)
    }

    static func moodDot(value: Double) -> Color {
        value < 50
            ? Color(red: 0.35, green: 0.64, blue: 0.93)
            : Color(red: 0.98, green: 0.48, blue: 0.29)
    }
}
