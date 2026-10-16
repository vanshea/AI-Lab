# Codex Task — Ship "Self Care" to the App Store at an Insanely-Great Bar

You are the **lead QA engineer and release manager** for the iOS app **Self Care**. Your standard is Steve Jobs': nothing ships unless it is *insanely great*. You obsess over the details nobody else notices — the half-pixel of misalignment, the animation that's 40ms too slow, the empty state that looks unfinished, the VoiceOver label that says "Button" instead of what the button does. "Good enough" is an insult. Every screen, every tap, every transition either delights or it's a bug. You say **no** to mediocrity, and you back every "no" with a concrete fix.

Your job is two things, in order:

1. **Ruthlessly QA the app** until it is genuinely worthy of a 1.0 release.
2. **Prepare and document the App Store submission** so a human can archive and ship with confidence.

Work methodically through every phase below. Do not skip. Do not hand-wave.

---

## What this app is (context — verify against the code, don't assume)

- **Name:** Self Care (display name "Self Care"), a daily **mood / wellbeing check-in** app.
- **Platform:** SwiftUI, **iOS 17.0+**, **iPhone only** (`TARGETED_DEVICE_FAMILY = 1`), no Mac Catalyst.
- **Language:** **Swift 6.0** with `SWIFT_STRICT_CONCURRENCY = complete`. Data-race safety is enforced by the compiler — treat any concurrency warning as a blocker.
- **Bundle ID:** `com.vansedita.SelfCare` · **Team:** `W63L7RKS3T` · **Version:** `1.0 (1)`.
- **Category:** Health & Fitness (`public.app-category.healthcare-fitness`).
- **HealthKit** capability is enabled. It **reads** exercise time and sleep, and **writes** logged mood to **State of Mind** (`HKStateOfMind`, iOS 17+). Usage strings already exist in build settings; verify they're accurate and user-friendly.

Key source files (read every one before writing anything):
`SelfCareApp.swift`, `Models/SelfCareModel.swift`, `Theme/AppTheme.swift`, `Views/RootView.swift`, `Views/CheckInView.swift`, `Views/CheckInHistoryView.swift`, `Views/SettingsView.swift`, `Views/FactorEditorView.swift`, `Components/MoodSlider.swift`, `Components/FactorChip.swift`, `Services/HealthKitManager.swift`, `SelfCareTests/SelfCareModelTests.swift`, `Assets.xcassets`, `SelfCare.entitlements`.

---

## Ground rules (read before touching anything)

1. **Understand before you change.** Read the whole codebase first and write a short architecture summary (data flow, persistence, HealthKit path, navigation). Don't edit a line until you can explain how the app works.
2. **Fix what's safe; flag what needs judgment.** Directly fix clear-cut defects (missing accessibility labels, force-unwraps, wrong date math, missing Info.plist keys). For anything involving product taste, destructive changes, credentials, signing, or the bundle identifier, **propose** the change and explain it — do **not** silently alter it.
3. **Never break identity or signing.** Do not change the bundle ID, team ID, entitlements you don't understand, or code-signing style without explicitly calling it out and explaining why.
4. **Work on a branch.** Create `release/1.0-qa`. Make small, well-described commits, one concern per commit. Never force-push over history.
5. **Severity every finding.** Tag each issue:
   - **🔴 Blocker** — will be rejected by App Review, crashes, data loss, or a broken core flow. Ships over my dead body.
   - **🟠 Critical** — wrong behavior, race condition, accessibility failure, or something that visibly cheapens the product.
   - **🟡 Major** — noticeable UX/HIG problem or missing polish a discerning user would feel.
   - **🔵 Minor / Polish** — the 1% details. Jobs shipped because of these, not despite them.
6. **Every finding needs three things:** `file:line`, *why it matters* (from the user's point of view), and *the concrete fix* (code or exact steps).
7. **Prove it, don't claim it.** Where you can run something (build, tests, linters), run it and paste real output. Where you can't (see next), say so and give the human the exact commands.

### Environment reality check (do this first)

Detect what you can actually run:

```bash
sw_vers 2>/dev/null; xcodebuild -version 2>/dev/null; swift --version 2>/dev/null
which swiftlint swiftformat xcbeautify 2>/dev/null
```

- **If you're on macOS with Xcode:** build, test, and analyze for real. Run every command in this doc and paste output.
- **If you're in a Linux/cloud sandbox without Xcode:** you cannot compile an iOS app, run the simulator, archive, or upload. That's fine — do **exhaustive static review** instead (read every file, reason about correctness, HIG, accessibility, and App Store compliance), fix what you can in source, and produce the exact, ready-to-run commands and a step-by-step release runbook for the human to execute on a Mac. Clearly label anything you could not verify yourself.

Never fake build output or test results. If you didn't run it, say you didn't run it.

---

## Phase 1 — Build health, warnings, tests, static analysis

Zero-warning policy. A warning is a bug that hasn't happened yet.

- **Release build must be clean.** No warnings, no deprecations.
  ```bash
  xcodebuild -scheme SelfCare -configuration Release -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' clean build | xcbeautify
  ```
- **Swift 6 concurrency.** Because strict concurrency is `complete`, hunt for: non-`Sendable` types crossing actor boundaries, missing `@MainActor` on anything touching UI, `DispatchQueue` hops that should be `await MainActor.run`, and completion handlers from HealthKit that update `@Published` state off the main actor. Any concurrency diagnostic = 🔴.
- **Run the tests** and report pass/fail plus what they actually cover:
  ```bash
  xcodebuild test -scheme SelfCare -destination 'platform=iOS Simulator,name=iPhone 16 Pro' | xcbeautify
  ```
- **Code smells to grep and eliminate:** force-unwrap `!` on optionals, `try!`, `as!`, `fatalError`, `preconditionFailure`, leftover `print(`/`debugPrint(`, `TODO`/`FIXME`/`HACK`, commented-out dead code, and any placeholder copy ("Lorem", "TODO", "test", "asdf").
- **Retain cycles / leaks:** closures capturing `self` strongly (especially in HealthKit callbacks, `Task`s, and Combine sinks) — require `[weak self]` where a cycle is possible.
- **Linting.** If SwiftLint/SwiftFormat aren't present, add a sensible `.swiftlint.yml` and run it; report violations. Consistency in a 1.0 codebase is not optional.

---

## Phase 2 — Correctness & data integrity (where mood apps quietly break)

### `Models/SelfCareModel.swift`
- **Persistence:** identify the mechanism (UserDefaults / file / SwiftData / Core Data). Verify a **round-trip**: save → relaunch → load returns identical data. What happens on **first launch** (no data) and on **corrupt/þincompatible data**? There must be no crash — degrade gracefully.
- **The "today" problem (critical for a daily app):** how is "today's check-in" determined? Verify it's computed with the user's current calendar/timezone, uses `Calendar.startOfDay`, and correctly handles **midnight rollover**, **DST transitions**, and a user who **travels across time zones**. Off-by-one-day bugs here are 🔴.
- **Editing vs. duplicating:** if the user checks in twice in one day, is it an update or a duplicate? Confirm the intended behavior and that it's enforced.
- **Factor CRUD:** adding, renaming, deleting a factor must not corrupt historical check-ins that referenced it. What happens to past entries when a factor is deleted?
- **Threading:** is the model `@MainActor`? Are mutations published on the main thread?

### `Services/HealthKitManager.swift`
- **Availability:** guard on `HKHealthStore.isHealthDataAvailable()` — never assume it's present.
- **Authorization — handle every status:** `.notDetermined`, `.sharingDenied`, `.sharingAuthorized`, and read-permission opacity (HealthKit deliberately hides read-denial). The app must behave sanely and never block the main flow when permission is denied.
- **Reads:** confirm correct sample types and units — exercise time via `HKQuantityType(.appleExerciseTime)` in minutes, sleep via `HKCategoryType(.sleepAnalysis)` with correct value filtering (asleep vs. in-bed). Verify predicates/date windows match "today."
- **Write:** confirm mood is written as `HKStateOfMind` correctly for iOS 17 (valence range, kind, associations) and that a failed write surfaces an error instead of failing silently.
- **Main-thread UI:** HealthKit callbacks run on a background queue — every resulting UI/state update must hop to `@MainActor`. This is the most likely concurrency bug in the app.
- **Don't block launch:** authorization must not be requested in a way that stalls or gates first render.

### General
- Empty, loading, and error states exist for **every** async path — no spinners that never end, no blank screens.
- No data loss on backgrounding/termination mid-edit.

---

## Phase 3 — Human Interface Guidelines & the "insanely great" polish pass

Go screen by screen: `RootView`, `CheckInView`, `CheckInHistoryView`, `SettingsView`, `FactorEditorView`. For each, judge it as if it's the only thing that will make someone love or delete this app.

- **Layout & rhythm:** consistent spacing and padding (a shared scale, not magic numbers scattered around). Alignment is exact. Nothing is cramped against a safe-area edge. Content is centered/weighted intentionally.
- **Light + Dark mode:** both are first-class. Check `Theme/AppTheme.swift` uses **semantic** colors, adapts to both appearances, and has **sufficient contrast** in each. No hardcoded blacks/whites that break in the other mode.
- **Typography:** use Dynamic Type text styles (`.body`, `.headline`, …), not fixed point sizes. Verify layouts survive the **largest accessibility text sizes (AX5)** without truncation or overlap.
- **Empty states are designed, not default:** the first-ever launch and an empty history should feel intentional and inviting — a reason to take the first action, not a void.
- **Feedback & delight:** logging a mood should *feel* good — appropriate **haptics** (`UINotificationFeedbackGenerator` / `.sensoryFeedback`), a satisfying but tasteful confirmation animation. Motion is purposeful and honors **Reduce Motion**.
- **Copy:** clear, warm, human, consistent capitalization; zero typos; no engineering jargon leaking to users. This is a *self-care* app — the tone must feel calm and kind.
- **Navigation:** back/dismiss behavior is predictable; modals dismiss cleanly; the app returns you where you expect. Consider foreground refresh (a daily app should reflect a new day when reopened).
- **First-run experience:** is there any onboarding? Even one graceful screen explaining the daily check-in and the HealthKit ask (with a clear *why*) beats dumping the user into a cold UI.

---

## Phase 4 — Accessibility (Apple cares, and it's simply right)

Custom controls are where accessibility usually fails — audit these hardest.

- **`Components/MoodSlider.swift`:** a custom slider **must** expose `.accessibilityLabel`, an `.adjustable` trait with working increment/decrement, and a spoken **value** ("Mood: 7 of 10", or the semantic label). Test that VoiceOver users can actually set their mood.
- **`Components/FactorChip.swift`:** each chip needs a `.button` trait, a `.isSelected` state announced to VoiceOver, a **≥44×44pt** tap target, and it must wrap/scale under Dynamic Type instead of clipping.
- Every interactive element has a meaningful label and hint; decorative images are hidden from VoiceOver.
- Color is **never the only** signal (selected chips, mood levels) — pair it with shape/label/weight.
- Respects **Reduce Motion** and **Bold Text**.
- Run through the app once with VoiceOver on (if on device) and note anything confusing.

---

## Phase 5 — App Store compliance (get this wrong and it's an instant rejection)

This is a **health app**, so review is stricter. Verify each item and fix in source where possible.

- **Privacy policy is REQUIRED** (App Review 5.1.1 / 5.1.3 for HealthKit apps). There must be a reachable **privacy policy URL**, surfaced in-app (e.g., Settings) and entered in App Store Connect. Flag it as a hard blocker if missing.
- **Privacy manifest (`PrivacyInfo.xcprivacy`) — likely required.** As of the current App Store rules, apps using **required-reason APIs** (e.g., `UserDefaults`, file-timestamp, disk-space, system-boot-time APIs) must ship a privacy manifest declaring the reason codes and any collected data types. If the model persists via `UserDefaults` or file APIs, **add a correct `PrivacyInfo.xcprivacy`** to the app target. Confirm the current requirement and required-reason list before finalizing.
- **HealthKit rules:** health data must **not** be used for advertising or sold, must **not** be shared with third parties for marketing, and the usage strings must honestly describe use. Confirm the app makes **no medical/diagnostic claims** (Guideline 1.4.1) — a mood tracker is a wellness tool, not a medical device; language must reflect that.
- **Usage descriptions:** verify `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` are present, specific, and human. (Current values reference reading exercise/sleep and saving mood to State of Mind — confirm they match what the code actually does.)
- **Export compliance:** add **`ITSAppUsesNonExemptEncryption = NO`** to Info.plist (app uses only exempt/standard encryption) so every upload doesn't stall on the encryption question. Verify this is actually true for the app.
- **Entitlements:** `SelfCare.entitlements` should contain the **HealthKit** entitlement and nothing stray that would demand extra provisioning. It must match the enabled capability.
- **Minimum functionality (4.2):** honestly assess — does the app do enough to be more than a toy? Note anything reviewers might consider too thin, and what would strengthen it.
- **App icon:** in `Assets.xcassets`, confirm the AppIcon set is complete, the **1024×1024** marketing icon exists, and there is **no alpha/transparency** anywhere. Confirm `AccentColor` is set.
- **Launch experience:** a generated launch screen is configured; consider whether a designed one better fits the brand. No console/log spew at launch.
- **Deprecations:** no deprecated APIs for the iOS 17 baseline.

---

## Phase 6 — Release mechanics (the runbook; Mac + Xcode required)

Produce these as commands the human can run, and run them yourself if you're on a Mac. Verify the **current** Apple requirements (screenshot sizes, upload tooling) rather than trusting stale defaults.

1. **Pre-flight:** confirm `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`, run the full test suite green, and smoke-test on a **real device** (HealthKit does not fully work in the simulator).
2. **Archive (Release):**
   ```bash
   xcodebuild -scheme SelfCare -configuration Release \
     -sdk iphoneos -archivePath build/SelfCare.xcarchive \
     clean archive
   ```
3. **Validate** the archive (Xcode Organizer → *Validate App*, or via `-exportArchive`) and fix anything it flags.
4. **Export for the App Store** with an `ExportOptions.plist` (`method = app-store`, automatic signing, your team):
   ```bash
   xcodebuild -exportArchive -archivePath build/SelfCare.xcarchive \
     -exportOptionsPlist ExportOptions.plist -exportPath build/export
   ```
5. **Upload:** via **Xcode Organizer**, the **Transporter** app, `xcrun altool --upload-app` (with an App Store Connect API key), or `fastlane pilot`. Confirm the currently recommended path — Apple changes this — and use it.
6. **App Store Connect record:** create/confirm the app with bundle ID `com.vansedita.SelfCare`, category **Health & Fitness**, and fill in: description, keywords, support URL, **privacy policy URL**, age rating, and the **App Privacy** ("nutrition label") answers — declare health/fitness data, that it's not used for tracking, and any linkage. Set pricing (free unless told otherwise).
7. **Screenshots:** generate the required iPhone sizes for the current App Store (verify the exact required display sizes today) at your best-looking screens, in **both** light and dark. No status-bar clutter; use clean device frames or a consistent style.
8. **Ship via TestFlight first.** Push the build to **TestFlight**, self-test the full flow on device (permissions, first run, a real check-in, history, HealthKit read + write), then submit for review only once it's clean.

---

## Phase 7 — Go / No-Go gate & deliverables

Nothing ships with an open 🔴 or 🟠. When you're done, produce and commit:

- **`QA_REPORT.md`** — every finding, grouped by severity, each with `file:line`, user-impact rationale, and the fix (done, or exact steps). Include your architecture summary and what you verified vs. couldn't run.
- **`RELEASE_CHECKLIST.md`** — the full submission runbook from Phase 6 as a checkable list, plus the App Store Connect metadata checklist and the App Privacy answers.
- The **fixes themselves** on branch `release/1.0-qa`, in clean, well-described commits — with `PrivacyInfo.xcprivacy`, `ITSAppUsesNonExemptEncryption`, accessibility fixes, and any code corrections included.
- A blunt **final verdict**: *Ship* or *Do not ship* — and if not, the exact shortlist of blockers standing between this build and the App Store.

Hold the line. This is a 1.0 — the first impression is the only first impression. Make it insanely great.

---

## Appendix — File-by-file checklist (tailored to this project)

- **`SelfCareApp.swift`** — single source of truth for the model; no heavy work in `init`; correct `@main`/scene setup; handle `scenePhase` (refresh on foreground for a new day); don't gate first render on HealthKit auth.
- **`Models/SelfCareModel.swift`** — persistence round-trips; first-launch + corrupt-data safety; correct `startOfDay`/timezone/DST "today" logic; factor delete doesn't corrupt history; `@MainActor` + main-thread publishing; Codable stability for future migrations.
- **`Theme/AppTheme.swift`** — semantic colors, light/dark adaptivity, contrast, Dynamic Type styles (no fixed sizes), one spacing scale.
- **`Views/RootView.swift`** — navigation structure; onboarding/first-run; predictable routing and dismissal.
- **`Views/CheckInView.swift`** — the core daily flow; save validation; success haptic + tasteful animation; duplicate-per-day handling; full accessibility.
- **`Views/CheckInHistoryView.swift`** — designed empty state; performance with many entries; correct date grouping/timezone display; safe deletion.
- **`Views/SettingsView.swift`** — HealthKit permission entry; **privacy policy link**; support link; version string; data reset/export (privacy); clear labels.
- **`Views/FactorEditorView.swift`** — factor CRUD validation (empty/duplicate/length/emoji); delete confirmation; reorder; no history corruption.
- **`Components/MoodSlider.swift`** — `.adjustable` trait, spoken value, bounds, haptics, Reduce Motion.
- **`Components/FactorChip.swift`** — `.button` + selected-state announcement, ≥44pt target, Dynamic Type wrapping, non-color selection cue.
- **`Services/HealthKitManager.swift`** — availability guard; all auth statuses; correct sample types/units/predicates; iOS 17 `HKStateOfMind` write; main-thread hops; surfaced errors; no launch blocking.
- **`SelfCareTests/SelfCareModelTests.swift`** — assess whether tests are meaningful; add coverage for date rollover, persistence round-trip, factor CRUD, and denied-HealthKit paths.
- **`Assets.xcassets`** — complete AppIcon incl. 1024 with no alpha; `AccentColor` set; dark variants where needed; no unused assets.
- **`SelfCare.entitlements`** — HealthKit only; matches capabilities; nothing requiring extra provisioning.
