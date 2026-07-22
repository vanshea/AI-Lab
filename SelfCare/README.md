# Self Care for iPhone

This is a native SwiftUI interpretation of the supplied `self_care.html` prototype. It requires iOS 17 or later and contains no web view or JavaScript runtime.

## Included

- Lock-screen-inspired check-in experience with live local date and time
- Draggable mood control with Low, Okay, Good, and Great ranges
- Tap-to-toggle daily factor chips and long-press factor setup
- Apple Health integration that reads today’s Exercise Time and last night’s Sleep Analysis
- Persistent check-in history with mood and daily-factor snapshots
- State of Mind export for logged moods on iOS 18 or later
- Manual fallback for every factor; scrolling stays manual because it is not a HealthKit data type
- First-run privacy and Apple Health explanation
- Tap-the-header minimize, theme, and background-resize interactions
- History, privacy details, CSV export, and local-data reset in Settings
- Automatic local-calendar day rollover when the app returns to the foreground
- Local persistence through `UserDefaults`
- VoiceOver labels, Dynamic Type support, semantic colors, and SF Symbols
- Unit tests for mood ranges, goal directions, persistence recovery, calendar/DST boundaries, Health query windows, export, and sleep-interval merging

## Open the project

Open `SelfCare.xcodeproj` in Xcode. Choose the `SelfCare` scheme and an iPhone simulator or connected iPhone, then press Run.

For exact device setup and troubleshooting, see [TESTING_ON_IPHONE.md](TESTING_ON_IPHONE.md).

## Prototype boundaries

The clock and wallpaper intentionally recreate the prototype inside the app. An iOS app cannot replace or draw freely over the real Lock Screen. A real Lock Screen surface would need a separate WidgetKit or Live Activity target and would use Apple’s more restricted layouts.

Exercise and sleep can read from HealthKit after the user grants access. On iOS 18 or later, logged moods can be saved to Apple Health as momentary State of Mind entries associated with self care. Complete check-in records remain local to the app. HealthKit does not expose general Screen Time totals, so scrolling remains a manual factor.
