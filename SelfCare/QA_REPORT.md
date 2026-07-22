# Self Care 1.0 QA Report

**Branch:** `release/1.0-qa`
**Candidate:** `1.0 (1)` · `com.vansedita.SelfCare` · iPhone · iOS 17+
**QA date:** July 22, 2026
**Verdict:** **DO NOT SHIP YET** — the app code is release-candidate quality, but the public privacy/support URLs and signed real-device/TestFlight gates are still open.

## Architecture summary

- `SelfCareApp` creates one `@MainActor` observable `SelfCareModel` and one `HealthKitManager`, then injects both into a SwiftUI `NavigationStack`.
- `RootView` owns app-level routing: check-in, factor editor sheets, first-run onboarding, and foreground refresh. It resets daily inputs when the user's local calendar day changes and refreshes HealthKit only after permission has previously been requested.
- `SelfCareModel` is the source of truth for theme, mood, the three fixed daily factors, onboarding state, and check-in history. A Codable state blob is persisted in this app's `UserDefaults`. Health-derived values are transient. Corrupt state recovers to safe defaults and displays a recovery message.
- The product intentionally supports multiple **momentary** check-ins per day. Records are immutable snapshots and sort newest-first. The three factors are fixed product concepts; the editor changes their input mode/value, not factor identity, so historical references cannot be orphaned by rename/delete.
- `HealthKitManager` is `@MainActor`. It asks for Health access only from user action, reads Apple Exercise Time and asleep Sleep Analysis intervals, and on iOS 18+ writes mood as `HKStateOfMind(kind: .momentaryEmotion, associations: [.selfCare])`. A local check-in succeeds even when HealthKit is unavailable or denied.
- Settings routes to History and Privacy and exposes factor setup, optional Apple Health, CSV export, reset, and the runtime version/build.

## Environment and proof

| Item | Result |
|---|---|
| macOS | 26.5.2 (25F84) |
| Xcode | 26.6 (17F113) |
| Swift | 6.3.3; project language mode Swift 6 with strict concurrency complete |
| SwiftLint | Official portable 0.65.0 used from `/tmp`; 0 violations in 14 files |
| Release simulator build | Succeeded |
| iPhone simulator tests | 17 executed, 0 failures |
| Release static analysis, physical iOS SDK | Succeeded |
| Unsigned Release archive, physical iOS SDK | Succeeded at `/tmp/SelfCareQA-ReleaseFinal.xcarchive` |
| Visual QA | iPhone 17 Pro and 17 Pro Max, iOS 26.5; onboarding, core check-in, Settings, History, Privacy, light/dark |
| Accessibility inspection | Native slider value/adjustability, factor selected states, coherent History row, meaningful Settings controls verified |

Representative real output:

```text
Done linting! Found 0 violations, 0 serious in 14 files.
Executed 17 tests, with 0 failures (0 unexpected) in 0.044 (0.049) seconds
** TEST SUCCEEDED **
** ANALYZE SUCCEEDED **
** ARCHIVE SUCCEEDED **
```

The build/analyze/archive logs contain one Xcode 26.6 toolchain notice:

```text
warning: Metadata extraction skipped. No AppIntents.framework dependency found.
```

This is emitted by Xcode's `appintentsmetadataprocessor` because the app correctly has no App Intents dependency. There are no Swift compiler, deprecation, asset-catalog, linker, analyzer, or strict-concurrency warnings. Adding an unused framework merely to silence the extractor would be the wrong fix.

## Findings

### 🔴 Blockers — open

1. **Public privacy policy and support endpoints are not supplied** — `PRIVACY_POLICY.md:25`, `SelfCare/Views/SettingsView.swift:132`
   **Why it matters:** A public privacy-policy URL is required for an iOS App Store submission, and HealthKit review expects the policy to be easy to reach. The app currently has an honest in-app policy, but no developer-owned HTTPS destination or monitored support contact was provided. Inventing either would be misleading.
   **Exact fix:** Publish `PRIVACY_POLICY.md` at a stable public HTTPS URL; replace its final placeholder paragraph with the monitored support email or page; add Privacy Policy and Support links in Settings; enter the same URLs in App Store Connect. Verify both in a clean production build.

2. **Signed distribution validation, TestFlight, and final real-device acceptance are incomplete** — `ExportOptions.plist:1`
   **Why it matters:** The unsigned archive proves physical-SDK compilation, but cannot prove the distribution certificate/profile, App Store Connect entitlements, server-side validation, or real Health database behavior. Shipping without this gate risks upload rejection or a broken permission flow.
   **Exact fix:** Follow `RELEASE_CHECKLIST.md`: make a signed Organizer archive, Validate App, upload to TestFlight, then complete the physical-iPhone matrix before selecting Submit for Review.

### 🟠 Critical — open release verification

1. **Every real-device HealthKit authorization branch still needs hands-on verification** — `SelfCare/Services/HealthKitManager.swift:84`, `SelfCare/Services/HealthKitManager.swift:133`
   **Why it matters:** Simulator/static proof cannot fully reproduce real Health permissions or the user's Health database. Read denial is intentionally opaque, and State of Mind write requires iOS 18+.
   **Exact fix:** On iOS 17 and current iOS hardware, test unavailable/no samples, allow, deny, later revoke, and retry. Confirm local logging always works; iOS 17 reports Health mood export unavailable; iOS 18+ writes exactly one State of Mind sample; denial explains the Settings path.

2. **Final assistive-technology/device matrix is not yet signed off by a human** — `SelfCare/Components/MoodSlider.swift:50`, `SelfCare/Components/FactorChip.swift:25`
   **Why it matters:** Programmatic accessibility inspection verified semantics, but release quality requires listening to the entire flow with VoiceOver and checking AX5, Bold Text, Reduce Motion, and both appearances on hardware.
   **Exact fix:** Run the accessibility section in `TESTING_ON_IPHONE.md`; record device/OS and pass/fail in the release checklist. Fix any clipping, confusing speech, or unreachable gesture before shipping.

### 🟠 Critical — resolved

1. **Corrupt persistence could not explain recovery** — `SelfCare/Models/SelfCareModel.swift:196`
   **User impact:** A damaged or incompatible state must never crash or silently leave a blank app.
   **Fix:** Decode is guarded; corruption restores safe defaults, records the current local day, reopens onboarding, and exposes a dismissible recovery message. Covered by automated test.

2. **Daily state did not have a robust local-calendar rollover contract** — `SelfCare/Models/SelfCareModel.swift:228`, `SelfCare/Views/RootView.swift:40`
   **User impact:** Mood/factors could appear to belong to the wrong day after midnight, DST, travel, or foregrounding.
   **Fix:** Persist a local year/month/day key, calculate with the user's current Calendar/start-of-day semantics, reset only daily inputs, preserve history/preferences, and refresh on foreground. DST and travel cases are tested.

3. **State of Mind denial needed an explicit error** — `SelfCare/Services/HealthKitManager.swift:139`
   **User impact:** A user could believe the mood reached Apple Health when write permission was off.
   **Fix:** Request only when not determined, require `.sharingAuthorized`, throw a localized denial with the Settings recovery path, and retain the local record with failed sync status.

4. **Custom mood slider exposed an invalid internal accessibility value** — `SelfCare/Components/MoodSlider.swift:50`
   **User impact:** VoiceOver inspection exposed `NaN` in addition to the semantic value.
   **Fix:** Use a native `Slider` accessibility representation with bounds, step-five adjustment, label, hint, and spoken semantic/numeric value. Inspector now reports `Value: 53; Details: Good, 53 out of 100`.

5. **Factor selection relied too heavily on color and small chip height** — `SelfCare/Components/FactorChip.swift:17`
   **User impact:** Low-vision, color-blind, motor, and VoiceOver users could miss state or struggle to activate a chip.
   **Fix:** Add an explicit checkmark, 44pt minimum height, button/selected traits, Goal met/not met value, edit action, and adaptive horizontal/vertical wrapping.

### 🟡 Major — resolved

1. **No first-run explanation before a sensitive-health feature** — `SelfCare/Views/RootView.swift:20`, `SelfCare/Views/WelcomeView.swift:3`
   **User impact:** A cold launch gave no context for local privacy, optional Health access, or non-medical scope.
   **Fix:** Added a polished, non-dismissible-without-action onboarding screen; Health permission remains user initiated later.

2. **Accessibility text sizes could crowd the lock-screen composition** — `SelfCare/Views/CheckInView.swift:22`
   **User impact:** AX-size text risked clipping the core action.
   **Fix:** Accessibility sizes switch to a scrollable layout; all copy uses Dynamic Type styles and fixed-height content is avoided.

3. **Motion and completion feedback needed platform preferences** — `SelfCare/Views/CheckInView.swift:29`
   **User impact:** Logging lacked satisfying confirmation, while card animations could ignore motion sensitivity.
   **Fix:** Add success sensory feedback and condition transitions/animations on Reduce Motion.

4. **Privacy control was incomplete** — `SelfCare/Views/SettingsView.swift:132`, `SelfCare/Models/SelfCareModel.swift:350`
   **User impact:** Users need to understand, export, and erase sensitive local wellbeing history.
   **Fix:** Added in-app privacy disclosure, CSV export, destructive reset with explicit confirmation, and clear Apple Health deletion caveat. Public URLs remain Blocker 1.

5. **Privacy manifest and export declaration were absent** — `SelfCare/PrivacyInfo.xcprivacy:1`, `SelfCare.xcodeproj/project.pbxproj:350`
   **User impact:** App Store validation can reject a binary that uses required-reason APIs without a declaration or leave export compliance unanswered.
   **Fix:** Ship `PrivacyInfo.xcprivacy` with UserDefaults reason `CA92.1`, no tracking/collection declarations, and `ITSAppUsesNonExemptEncryption = NO` in both app configurations.

6. **Entitlements requested more than the app uses** — `SelfCare/SelfCare.entitlements:5`
   **User impact:** Unnecessary health-record/background capabilities expand review and provisioning risk.
   **Fix:** Entitlements now contain HealthKit only. Bundle ID, team ID, automatic signing style, and product identity were not changed.

7. **History placement and card minimization did not match the requested information architecture** — `SelfCare/Views/SettingsView.swift:24`, `SelfCare/Views/CheckInView.swift:240`
   **User impact:** Extra top-level controls crowded the core header.
   **Fix:** History lives in Settings; the separate minimize button is gone; tapping the icon/name/goal area minimizes and leaves more room for the updated brand.

### 🔵 Minor / polish — resolved or accepted

1. **App Store screenshots were not submission-ready** — `AppStore/Screenshots/6.9-inch/01-welcome-dark.png:1`
   **User impact:** Wrong dimensions or alpha can fail upload and inconsistent appearance weakens the product page.
   **Fix:** Generated six consistent 1320×2868 screenshots across dark and light, then removed alpha from every PNG.

2. **Style gate was missing** — `.swiftlint.yml:1`
   **User impact:** Force unwraps, force casts, long lines, and accessibility image omissions can regress unnoticed.
   **Fix:** Added a strict project configuration and ran official SwiftLint 0.65.0: 0 violations.

3. **Xcode App Intents extractor warning** — `SelfCare.xcodeproj/project.pbxproj:1`
   **User impact:** No in-app impact; it creates noise in an otherwise clean log.
   **Disposition:** Accepted Xcode 26.6 toolchain exception. The app has no App Intents and should not link an unused framework. Recheck with the next stable Xcode and require all app-owned diagnostics to remain at zero.

## Correctness decisions

- **More than one check-in per day:** intentional. Each entry is a momentary mood snapshot, consistent with the HealthKit sample kind. Entries are not silently overwritten.
- **Factors:** intentionally fixed to Exercise, Sleep, and Scrolling. `FactorEditorView` edits mode/value; it is not arbitrary CRUD. Historical snapshots therefore remain stable. Custom factor CRUD is a future product feature, not a 1.0 defect.
- **State of Mind availability:** the pasted brief calls it iOS 17+, but the SDK API used by this project is available on iOS 18+. The code correctly guards iOS 18 and keeps all iOS 17 check-ins local.
- **App Privacy label:** current code does not transmit user data to the developer or third parties. Under Apple's definition, on-device processing is not “collection,” so the accurate App Store Connect answer is **No, we do not collect data from this app**. HealthKit use is still disclosed in policy, review notes, usage strings, and UI.

## Compliance references

- [App privacy details and Apple's definition of collection](https://developer.apple.com/app-store/app-privacy-details/)
- [Manage app privacy and required policy URL](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [HealthKit user privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Required-reason API declarations](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [Current screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
