# Self Care 1.0 — QA and release-readiness report

## Architecture summary

1. The app is a single-target SwiftUI iPhone app with an iOS 17.0 deployment target.
2. `SelfCareApp` owns the observable model, HealthKit manager, and local reminder service.
3. `RootView` refreshes the local day and previously requested Health data on launch and foreground return.
4. `CheckInView` presents the mood slider, daily factors, custom categories, and full/compact/minimal panel states.
5. `SelfCareModel` stores Codable state in app-scoped `UserDefaults`; there is no account or developer backend.
6. Check-ins are immutable snapshots; multiple momentary entries on one local calendar day are allowed.
7. Factors are manual or read-only HealthKit values: Apple Exercise Time (minutes) and asleep-stage sleep (hours).
8. `HealthKitManager` owns optional authorization, sample queries, and iOS 18+ State of Mind export.
9. Settings contains reminders, appearance, factor setup, privacy details, CSV export, reset, and Health controls.
10. The app target bundles `PrivacyInfo.xcprivacy`, the HealthKit entitlement, `Assets.xcassets`, and a generated launch screen.

## Baseline before this turn’s changes

The checkout already contained the prior requested icon, check-in, factor-toggle, and reminder work. Those pre-existing edits were preserved on the requested `release/1.0-prep` branch.

| Check | Result |
|---|---|
| Xcode / SDK | Xcode 27.0 (27A266a); iOS 27.0 SDK |
| Shared scheme | `SelfCare.xcodeproj/xcshareddata/xcschemes/SelfCare.xcscheme` exists |
| Debug simulator build | Passed; 1 Xcode App Intents metadata-extractor warning |
| Release simulator build | Passed; 1 Xcode App Intents metadata-extractor warning |
| Simulator tests | 24 passed, 0 failed |
| Warning interpretation | The sole warning is Xcode’s “Metadata extraction skipped, no AppIntents.framework dependency found”; there are no app-owned Swift warnings in these logs. |

The first sandboxed compiler invocation could not start Swift’s Observation macro plug-in. Re-running the same build with the necessary Xcode tool access succeeded; this was an execution restriction, not a source diagnostic.

## Changes and after-results

- Added explicit portrait-only orientation and Release hardening (`VALIDATE_PRODUCT`, assertions off, `-O`, standard warning flags, and Swift warnings-as-errors).
- Kept bundle ID, team, automatic signing, iOS 17.0 deployment target, iPhone-only family, and HealthKit capability unchanged.
- Confirmed the built product’s `Info.plist` contains display name `Self Care`, version `1.0`, build `4`, `ITSAppUsesNonExemptEncryption = false`, both Health usage strings, a generated launch screen, and only portrait iPhone orientation.
- Confirmed `PrivacyInfo.xcprivacy` is valid, bundled, declares UserDefaults reason `CA92.1`, has tracking off, and has no collected-data declarations. Source inspection found only app-scoped `UserDefaults` among the required-reason API families.
- Added stable HealthKit sync identifiers and increasing sync versions for app-written State of Mind samples; added deliberate factor/category association mapping and deletion when a locally stored exported entry is deleted or reset.
- Added a HealthKit availability seam and tests for the unavailable-device path; local check-ins still succeed in that path.
- Exposed the unconfigured hosted privacy-policy URL in Settings rather than inventing a URL.

| Check | Result |
|---|---|
| Debug simulator build | Passed; 1 Xcode App Intents metadata-extractor warning |
| Release simulator build | Passed; 1 Xcode App Intents metadata-extractor warning |
| Simulator tests | 27 passed, 0 failed; 2 copies of the same Xcode metadata-extractor warning (app and test products) |
| Release settings | `VALIDATE_PRODUCT=YES`, `ENABLE_NS_ASSERTIONS=NO`, `SWIFT_OPTIMIZATION_LEVEL=-O`, `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`, complete concurrency checking |
| Unsigned Release archive | `ARCHIVE SUCCEEDED`; final archive at `/tmp/SelfCare-final.xcarchive` |
| Archive contents | App identity, privacy manifest, and generated Info.plist keys verified. Archive has no distribution signature/profile and was not Organizer-validated or uploaded. |

## Findings

### 🔴 Blockers

1. **Hosted privacy policy and monitored support contact are still placeholders** — `SelfCare/Views/SettingsView.swift` and `PRIVACY_POLICY.md`.
   **User/review impact:** App Store Connect requires a public privacy-policy URL for this HealthKit app; the Settings row currently states that the online URL is not configured. A contact placeholder is not a support channel.
   **Fix:** Host the final policy on public HTTPS, replace `AppStoreLinks.privacyPolicyURLString`, add the real support contact, and verify both from a device.

2. **Health-to-app reconciliation is not implemented** — `SelfCare/Services/HealthKitManager.swift` and `SelfCare/Views/RootView.swift`.
   **User impact:** Self Care can upsert and delete its own State of Mind samples, but does not observe edits/deletions performed in Apple Health. The local history can therefore still say “Saved to Apple Health” after a person deletes the Health entry.
   **Fix:** Decide whether local history is authoritative or mirrored. If mirrored, add a State of Mind anchored query scoped to Self Care’s source, persist its anchor, process deletion events without interpreting hidden read denial as deletion, and test on a physical iPhone. No unsupported iOS 27 API was invented.

3. **The archive is unsigned and distribution validation remains outstanding** — `/tmp/SelfCare-final.xcarchive` and `RELEASE_CHECKLIST.md`.
   **User/review impact:** The unsigned archive proves compilation and package structure only; it cannot prove App Store signing, provisioning, or distribution validation.
   **Fix:** In Xcode Organizer, create/validate a signed archive with the existing automatic-signing team and HealthKit capability. Do not upload until validation passes.

4. **Required HealthKit checks need a physical device** — `TESTING_ON_IPHONE.md`.
   **User impact:** Simulator unit tests cannot prove prompts, Apple Health sample appearance/source, permission revocation, or delete/update behavior. No physical-device HealthKit matrix was run in this session.
   **Fix:** Complete the real-device matrix in `HUMAN_TODO.md` on iOS 17 and current public iOS 27, including the 27.2 beta only if the owner chooses to test it.

### 🟠 Critical / 🟡 Major follow-ups

5. **State of Mind labels remain intentionally empty** — `SelfCare/Services/HealthKitManager.swift`.
   **User impact:** The slider captures valence, not a specific emotion; mapping “Low/Good/Great” to Apple’s emotion labels would invent feelings for the person.
   **Fix:** Keep labels empty for 1.0 or approve an explicit emotion-choice control and map only the user’s own selection. Associations are limited to meaningful matches and documented in `HEALTH_INTEGRATION.md`.

6. **The full visual/accessibility screenshot matrix was not captured from this build** — `AppStore/Screenshots/6.9-inch/01-welcome-dark.png`.
   **User impact:** Existing 6.9-inch PNGs meet current pixel/alpha requirements, but they predate this build and do not demonstrate smallest/largest iPhone, AX5, or all five views in both appearances. Simulator service became unavailable after test execution.
   **Fix:** Capture and inspect the current build at default and AX5 text sizes on the smallest and largest available iPhone simulators, in light and dark. Replace the submission set only after visual review.

7. **The HealthKit unavailable seam is tested, not a real denied-read state** — `SelfCareTests/SelfCareModelTests.swift`.
   **User impact:** HealthKit intentionally hides read denial; a no-data result can mean either denial or no samples. The UI reports “No readable data” and preserves manual/local use, but a physical denial/revocation test remains essential.
   **Fix:** Run allow, deny, partial allow, and revoke scenarios on device and verify the current no-data explanation is understandable.

## Verified versus not verified

**Verified locally:** project and shared scheme load; Debug and Release simulator builds pass; 27 unit tests pass; Release settings resolve as intended; built Info.plist and privacy manifest are present and correct; source entitlement contains only HealthKit; Xcode project enables the HealthKit capability; no tracked `xcuserdata`/`.xcuserstate`; `.gitignore` covers Xcode user state; the App Store icon target is `SelfCareColorIcon` and the catalog builds.

**Not verified:** signed distribution/provisioning profile, App Store Connect processing/validation, hosted policy/support URLs, app-name availability, age-rating answers, HealthKit behavior on hardware, real app icon in Health data-source screens, screenshots from the final build at AX5/light/dark/small+large sizes, and Health-originated State of Mind edits/deletions.

## Verdict

**Do not ship yet.** Resolve the four 🔴 items above, complete the HealthKit device matrix, decide the one-way versus mirrored Health history boundary, and review fresh screenshots before submission.
