# Apple Health / HealthKit integration

## What the current SDK and Apple documentation say

The project builds with Xcode 27.0 and the installed iOS 27.0 SDK. The SDK’s `HKStateOfMind.h` declares `HKStateOfMind`, its `Kind`, `Label`, and `Association` enums, and `HKObjectType.stateOfMindType()` as available starting in iOS 18.0. This corrects the original task’s assumption that State of Mind writing is available from iOS 17. The app keeps its iOS 17 deployment target and gates State of Mind export at iOS 18.

The installed iOS 27 SDK contains no new State of Mind sample type or API used by this app beyond the documented HealthKit interface. Apple’s iOS 27 HealthKit release notes discuss workout zones, menopause-related samples, and a limited/full history permission flow; those additions do not apply to this app’s Exercise Time, Sleep Analysis, or State of Mind flow. Apple’s iOS 27.2 beta notes mention a Health Insights issue, not a new third-party Health integration API. No Health app URL scheme, entitlement, or private API was added.

Apple references:

- [HKStateOfMind](https://developer.apple.com/documentation/healthkit/hkstateofmind) — initializer and properties.
- [HKStateOfMind.Kind](https://developer.apple.com/documentation/healthkit/hkstateofmind/kind-swift.enum) — `momentaryEmotion` and `dailyMood`.
- [HKStateOfMind.Association](https://developer.apple.com/documentation/healthkit/hkstateofmind/association) — documented association cases.
- [HealthKit updates](https://developer.apple.com/documentation/updates/healthkit) and [iOS 27 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes).
- [iOS 27.2 beta release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27_2-release-notes).
- [HealthKit privacy guidance](https://developer.apple.com/design/human-interface-guidelines/healthkit/).

## Current integration behavior

| Data | Direction | When requested | Behavior |
|---|---|---|---|
| Apple Exercise Time | Read | When connecting the category or choosing Apple Health for Exercise | Sum in minutes over the current local calendar day. No samples/read denial leaves the manual and local check-in usable. |
| Sleep Analysis | Read | When connecting the category or choosing Apple Health for Sleep | Count only asleep-stage values, clip to the prior evening-to-current-noon window, merge overlapping intervals, and report hours. In-bed/awake samples are not counted. |
| State of Mind | Write | Only after enabling “Save check-in mood to State of Mind” in Settings; iOS 18+ | Save one `momentaryEmotion` sample using the check-in timestamp and valence. On iOS 17, the check-in remains local. |

HealthKit read authorization is requested in context; the app does not block first render or ask at launch. HealthKit does not reveal read denial to the app, so “No readable data” intentionally does not claim that the person denied access. Manual factors and local history remain available.

## State of Mind mapping

- **Kind:** `.momentaryEmotion`, because the prompt asks “How are you feeling right now?” rather than asking for an all-day summary.
- **Valence:** `clamp((sliderValue / 50) - 1, -1, 1)`. Slider 0 → −1, 50 → 0, 100 → +1. Tests cover endpoints, midpoint, and clamping.
- **Labels:** `[]` for 1.0. “Low / Okay / Good / Great” are slider ranges, not specific feelings. Mapping a range to “sad,” “calm,” or “happy” would invent an emotion the person did not select. An explicit emotion-choice control needs product approval before adding Health labels.
- **Associations:** only completed/relevant factors and exact custom-category names map to Apple’s documented associations. Exercise with a positive captured value maps to `.fitness`; a sleep goal met maps to `.health`. Exact custom names such as “Work,” “Family,” “Yoga,” and “Meditation” map to their corresponding `.work`, `.family`, `.fitness`, and `.selfCare` values. Unrecognized names are omitted rather than guessed. Duplicate associations are removed.

## Update and deletion semantics

Each local record has a deterministic sync identifier (`com.vansedita.SelfCare.checkin.<UUID>`). Each save/retry increments and persists its `HKMetadataKeySyncVersion`; HealthKit replaces an object with the same sync identifier when the new version is greater. Deleting an exported record in Self Care or resetting data asks HealthKit to delete objects with that sync identifier. If deletion fails during reset, the local reset is canceled and the user sees the error. These paths compile, but they have not been exercised against real HealthKit on a physical iPhone.

**Important one-way boundary:** the current app does not query State of Mind history or consume HealthKit deletion anchors. An edit or deletion performed directly in Apple Health therefore does not update the local Self Care history/sync status. HealthKit also hides read denial, so a naïve “sample missing” query cannot safely be interpreted as a deletion. A source-scoped `HKAnchoredObjectQuery` and a user-approved read permission are the likely next step if the product wants mirrored history; do not ship a claim that edits/deletions stay synchronized until that is implemented and device-tested. This is an open release blocker in `HUMAN_TODO.md`.

## App identity and permissions

The built app display name is `Self Care`, and the app icon build setting points to `SelfCareColorIcon`. The source entitlement contains only `com.apple.developer.healthkit`; the Xcode project declares the HealthKit capability. The final signed profile/App ID capability must still be checked during Organizer validation. Usage strings say the app reads exercise time/sleep duration and saves logged moods to State of Mind.

## Test matrix

| Scenario | Result |
|---|---|
| Valence endpoints/midpoint/clamp | Automated unit tests pass |
| Association mapping and no false `.selfCare` for unrelated categories | Automated unit test passes |
| HealthKit unavailable; local check-in still saves | Injected availability test passes |
| Exercise/sleep calendar windows across spring DST | Automated unit test passes |
| HealthKit read denied/partial/revoked | Not tested on a physical device |
| State of Mind sample visible with correct source, valence and associations | Not tested on a physical device |
| Re-save replacement, HealthKit deletion and reset deletion | Not tested against real HealthKit on a physical device |
| Delete or edit sample in Apple Health and reconcile in Self Care | Not implemented; see one-way boundary above |
| Current public iOS 27 device | Not tested on hardware; iOS 27.0 simulator unit suite passed |
| iOS 27.2 beta redesigned Health | Not tested; installed Xcode/runtime is 27.0. Do not depend on beta-only behavior. |

The full 27-test result and build logs are summarized in `QA_REPORT.md`. A simulator cannot substitute for the physical-device HealthKit matrix.
